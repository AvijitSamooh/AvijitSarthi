import { BadRequestException, InternalServerErrorException } from '@nestjs/common';
import sharp from 'sharp';
import { MediaService } from './media.service';

describe('MediaService', () => {
  let service: MediaService;
  let r2: { upload: jest.Mock; delete: jest.Mock; download: jest.Mock };
  let firebaseStorage: { upload: jest.Mock; delete: jest.Mock; download: jest.Mock; getSignedUrl: jest.Mock };
  let firestore: { upsert: jest.Mock; getById: jest.Mock; delete: jest.Mock };
  let firebase: { db: { collection: jest.Mock } };

  beforeEach(() => {
    r2 = { upload: jest.fn(), delete: jest.fn(), download: jest.fn().mockResolvedValue(Buffer.from('r2-image')) };
    firebaseStorage = {
      upload: jest.fn(),
      delete: jest.fn(),
      download: jest.fn().mockResolvedValue(Buffer.from('private-image')),
      getSignedUrl: jest.fn().mockResolvedValue('https://signed.example/private-image'),
    };
    firestore = { upsert: jest.fn(), getById: jest.fn(), delete: jest.fn() };
    const query = {
      count: jest.fn(() => ({ get: jest.fn().mockResolvedValue({ data: () => ({ count: 0 }) }) })),
    };
    firebase = { db: { collection: jest.fn(() => ({ where: jest.fn(() => query), get: jest.fn() })) } };
    service = new MediaService(r2 as never, firebaseStorage as never, firestore as never, firebase as never);
  });

  const createFile = (overrides: Partial<Express.Multer.File> = {}): Express.Multer.File =>
    ({
      buffer: Buffer.from('not-used-for-validation'),
      mimetype: 'image/jpeg',
      size: 1024,
      ...overrides,
    }) as Express.Multer.File;

  async function validImage(format: 'jpeg' | 'png' = 'jpeg') {
    const image = sharp({
      create: {
        width: 100,
        height: 100,
        channels: 3,
        background: { r: 255, g: 255, b: 255 },
      },
    });
    return format === 'png' ? image.png().toBuffer() : image.jpeg().toBuffer();
  }

  it('rejects a missing file', async () => {
    await expect(service.uploadImage(undefined as never)).rejects.toBeInstanceOf(BadRequestException);
    expect(r2.upload).not.toHaveBeenCalled();
    expect(firebaseStorage.upload).not.toHaveBeenCalled();
  });

  it('rejects invalid image bytes regardless of multipart MIME type', async () => {
    await expect(service.uploadImage(createFile({ mimetype: 'application/pdf' }))).rejects.toBeInstanceOf(BadRequestException);
    expect(r2.upload).not.toHaveBeenCalled();
  });

  it('uploads public admin content to R2 and records its provider', async () => {
    const input = await validImage();
    const persisted = { id: 'media-1', storageKey: 'uploads/media-1.webp', storageProvider: 'R2' };
    firestore.upsert.mockImplementation(async (value: any) => ({ ...value, ...persisted }));

    await expect(service.uploadImage(createFile({ buffer: input, mimetype: 'application/octet-stream', size: input.length }))).resolves.toMatchObject(persisted);
    expect(r2.upload).toHaveBeenCalledWith(expect.stringMatching(/^uploads\/.+\.webp$/), expect.any(Buffer), 'image/webp');
    expect(firebaseStorage.upload).not.toHaveBeenCalled();
    expect(firestore.upsert).toHaveBeenCalledWith(expect.objectContaining({ storageProvider: 'R2' }));
  });

  it('rejects files larger than 10 MB', async () => {
    await expect(service.uploadImage(createFile({ size: 10 * 1024 * 1024 + 1 }))).rejects.toBeInstanceOf(BadRequestException);
    expect(r2.upload).not.toHaveBeenCalled();
  });

  it('processes a valid image, uploads WebP, and persists optimized metadata', async () => {
    const input = await sharp({
      create: { width: 2400, height: 1200, channels: 3, background: { r: 255, g: 255, b: 255 } },
    }).jpeg().toBuffer();
    firestore.upsert.mockImplementation(async (value: any) => value);

    const result = await service.uploadImage(createFile({ buffer: input, size: input.length }));
    expect(result).toMatchObject({ mimeType: 'image/webp', width: 1600, height: 800, storageProvider: 'R2' });
    const uploaded = r2.upload.mock.calls[0][1] as Buffer;
    const metadata = await sharp(uploaded).metadata();
    expect(metadata.format).toBe('webp');
    expect(metadata.width).toBe(1600);
    expect(metadata.height).toBe(800);
    expect(firestore.upsert).toHaveBeenCalledWith(expect.objectContaining({
      storageKey: expect.stringMatching(/^uploads\/.+\.webp$/),
      storageProvider: 'R2',
      mimeType: 'image/webp',
      width: 1600,
      height: 800,
      fileSize: uploaded.length,
    }));
  });

  it('uses the requested public content folder in R2', async () => {
    const input = await validImage('png');
    firestore.upsert.mockImplementation(async (value: any) => value);
    await service.uploadImage(createFile({ buffer: input, mimetype: 'image/png', size: input.length }), 'organisations');
    expect(r2.upload).toHaveBeenCalledWith(expect.stringMatching(/^organisations\/.+\.webp$/), expect.any(Buffer), 'image/webp');
    expect(firebaseStorage.upload).not.toHaveBeenCalled();
  });

  it('keeps applicant uploads in private Firebase Storage', async () => {
    const input = await validImage('png');
    firestore.upsert.mockImplementation(async (value: any) => value);
    const result = await service.uploadImage(
      createFile({ buffer: input, mimetype: 'image/png', size: input.length }),
      'applications',
      'user-1',
    );

    expect(firebaseStorage.upload).toHaveBeenCalledWith(expect.stringMatching(/^applications\/.+\.webp$/), expect.any(Buffer), 'image/webp');
    expect(r2.upload).not.toHaveBeenCalled();
    expect(result).toMatchObject({ uploadedById: 'user-1', storageProvider: 'FIREBASE_STORAGE' });
  });

  it('deletes the R2 object when Firestore persistence fails', async () => {
    const input = await validImage();
    firestore.upsert.mockRejectedValue(new Error('Firestore unavailable'));
    await expect(service.uploadImage(createFile({ buffer: input, size: input.length }))).rejects.toBeInstanceOf(InternalServerErrorException);
    expect(r2.delete).toHaveBeenCalledWith(expect.stringMatching(/^uploads\/.+\.webp$/));
  });

  it('deletes the Firebase object when private application metadata persistence fails', async () => {
    const input = await validImage();
    firestore.upsert.mockRejectedValue(new Error('Firestore unavailable'));
    await expect(service.uploadImage(createFile({ buffer: input, size: input.length }), 'applications', 'user-1')).rejects.toBeInstanceOf(InternalServerErrorException);
    expect(firebaseStorage.delete).toHaveBeenCalledWith(expect.stringMatching(/^applications\/.+\.webp$/));
    expect(r2.delete).not.toHaveBeenCalled();
  });

  it('returns an internal error when R2 upload fails', async () => {
    const input = await validImage();
    r2.upload.mockRejectedValue(new Error('R2 unavailable'));
    await expect(service.uploadImage(createFile({ buffer: input, size: input.length }))).rejects.toBeInstanceOf(InternalServerErrorException);
    expect(firestore.upsert).not.toHaveBeenCalled();
  });

  it('downloads using the recorded provider and defaults legacy records to Firebase Storage', async () => {
    await expect(service.downloadImage({ storageKey: 'uploads/new.webp', storageProvider: 'R2' })).resolves.toEqual(Buffer.from('r2-image'));
    await expect(service.downloadImage({ storageKey: 'applications/old.webp', storageProvider: 'FIREBASE_STORAGE' })).resolves.toEqual(Buffer.from('private-image'));
    expect(r2.download).toHaveBeenCalledWith('uploads/new.webp');
    expect(firebaseStorage.download).toHaveBeenCalledWith('applications/old.webp');
  });

  it('returns public R2 URLs and signed Firebase URLs', async () => {
    const previous = process.env.R2_PUBLIC_BASE_URL;
    process.env.R2_PUBLIC_BASE_URL = 'https://cdn.example/';
    await expect(service.getReadUrl({ storageKey: 'uploads/a file.webp', storageProvider: 'R2' })).resolves.toBe('https://cdn.example/uploads/a%20file.webp');
    await expect(service.getReadUrl({ storageKey: 'applications/private.webp', storageProvider: 'FIREBASE_STORAGE' })).resolves.toBe('https://signed.example/private-image');
    expect(firebaseStorage.getSignedUrl).toHaveBeenCalledWith('applications/private.webp');
    if (previous === undefined) delete process.env.R2_PUBLIC_BASE_URL;
    else process.env.R2_PUBLIC_BASE_URL = previous;
  });

  it('requires a public base URL before returning an R2 media URL', async () => {
    const previous = process.env.R2_PUBLIC_BASE_URL;
    delete process.env.R2_PUBLIC_BASE_URL;
    await expect(service.getReadUrl({ storageKey: 'uploads/a.webp', storageProvider: 'R2' })).rejects.toBeInstanceOf(InternalServerErrorException);
    if (previous === undefined) delete process.env.R2_PUBLIC_BASE_URL;
    else process.env.R2_PUBLIC_BASE_URL = previous;
  });

  it('enforces owner and reference guards and deletes from the recorded provider', async () => {
    const media: any = { id: 'm1', uploadedById: 'u1', storageKey: 'uploads/m1.webp', storageProvider: 'R2' };
    firestore.getById.mockResolvedValue(media);
    await expect(service.deleteUserImage('m1', 'u2')).rejects.toThrow();
    await expect(service.deleteUserImage('m1', 'u1')).resolves.toEqual({ id: 'm1', deleted: true });
    expect(r2.delete).toHaveBeenCalledWith('uploads/m1.webp');
    expect(firestore.delete).toHaveBeenCalledWith('m1');

    firestore.getById.mockResolvedValue({ ...media, storageProvider: undefined });
    await expect(service.deleteUserImage('m1', 'u1')).resolves.toEqual({ id: 'm1', deleted: true });
    expect(firebaseStorage.delete).toHaveBeenCalledWith('uploads/m1.webp');

    const query = { count: jest.fn(() => ({ get: jest.fn().mockResolvedValue({ data: () => ({ count: 2 }) })) })) };
    firebase.db.collection.mockReturnValue({ where: jest.fn(() => query) });
    firestore.getById.mockResolvedValue(media);
    await expect(service.deleteUserImage('m1', 'u1')).rejects.toThrow(BadRequestException);
  });
});
