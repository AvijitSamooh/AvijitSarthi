import { InternalServerErrorException } from '@nestjs/common';
import { getStorage } from 'firebase-admin/storage';
import { FirebaseStorageService } from './firebase-storage.service';

jest.mock('firebase-admin/storage', () => ({ getStorage: jest.fn() }));

describe('FirebaseStorageService', () => {
  const originalEnv = process.env;
  const save = jest.fn();
  const download = jest.fn();
  const remove = jest.fn();
  const exists = jest.fn();
  const getSignedUrl = jest.fn();
  const bucket = { exists, file: jest.fn(() => ({ save, download, delete: remove, getSignedUrl })) };

  beforeEach(() => {
    jest.restoreAllMocks();
    jest.clearAllMocks();
    process.env = { ...originalEnv, FIREBASE_STORAGE_BUCKET: 'test-project.firebasestorage.app' };
    (getStorage as jest.Mock).mockReturnValue({ bucket: jest.fn(() => bucket) });
    exists.mockResolvedValue([true]);
    save.mockResolvedValue(undefined);
    download.mockResolvedValue([Buffer.from('image')]);
    remove.mockResolvedValue(undefined);
    getSignedUrl.mockResolvedValue(['https://signed.example/image.webp']);
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('verifies that the configured bucket exists', async () => {
    await expect(new FirebaseStorageService().verifyConnection()).resolves.toBeUndefined();
    expect(getStorage).toHaveBeenCalled();
    expect(bucket.exists).toHaveBeenCalled();
  });

  it('rejects a missing bucket configuration', async () => {
    delete process.env.FIREBASE_STORAGE_BUCKET;
    await expect(new FirebaseStorageService().verifyConnection()).rejects.toBeInstanceOf(InternalServerErrorException);
  });

  it('wraps bucket connectivity errors', async () => {
    exists.mockRejectedValue(new Error('denied'));
    await expect(new FirebaseStorageService().verifyConnection()).rejects.toThrow('Unable to connect to Firebase Storage bucket.');
  });

  it('uploads objects with content type metadata', async () => {
    const body = Buffer.from('image');
    await new FirebaseStorageService().upload('uploads/image.webp', body, 'image/webp');
    expect(bucket.file).toHaveBeenCalledWith('uploads/image.webp');
    expect(save).toHaveBeenCalledWith(body, { resumable: false, metadata: { contentType: 'image/webp' } });
  });

  it('wraps upload errors', async () => {
    save.mockRejectedValue(new Error('denied'));
    await expect(new FirebaseStorageService().upload('image.webp', Buffer.from('x'), 'image/webp')).rejects.toThrow('Unable to upload image to Firebase Storage.');
  });

  it('downloads object bytes', async () => {
    await expect(new FirebaseStorageService().download('image.webp')).resolves.toEqual(Buffer.from('image'));
  });

  it('wraps download errors', async () => {
    download.mockRejectedValue(new Error('missing'));
    await expect(new FirebaseStorageService().download('image.webp')).rejects.toThrow('Unable to download image from Firebase Storage.');
  });

  it('creates temporary read URLs for private application media', async () => {
    jest.spyOn(Date, 'now').mockReturnValue(1_000);
    await expect(new FirebaseStorageService().getSignedUrl('applications/photo.webp', 60_000)).resolves.toBe('https://signed.example/image.webp');
    expect(bucket.file).toHaveBeenCalledWith('applications/photo.webp');
    expect(getSignedUrl).toHaveBeenCalledWith({ action: 'read', expires: 61_000 });
  });

  it('wraps signed URL errors', async () => {
    getSignedUrl.mockRejectedValue(new Error('denied'));
    await expect(new FirebaseStorageService().getSignedUrl('applications/photo.webp')).rejects.toThrow('Unable to create a temporary read URL for Firebase Storage.');
  });

  it('deletes objects while ignoring missing objects', async () => {
    await new FirebaseStorageService().delete('image.webp');
    expect(remove).toHaveBeenCalledWith({ ignoreNotFound: true });
  });

  it('wraps delete errors', async () => {
    remove.mockRejectedValue(new Error('denied'));
    await expect(new FirebaseStorageService().delete('image.webp')).rejects.toThrow('Unable to delete image from Firebase Storage.');
  });
});
