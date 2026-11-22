import { MediaController } from './media.controller';

describe('MediaController', () => {
  let controller: MediaController;
  let mediaService: { uploadImage: jest.Mock };
  let r2StorageService: { verifyConnection: jest.Mock };
  let firebaseStorageService: { verifyConnection: jest.Mock };

  beforeEach(() => {
    mediaService = { uploadImage: jest.fn() };
    r2StorageService = { verifyConnection: jest.fn() };
    firebaseStorageService = { verifyConnection: jest.fn() };
    controller = new MediaController(mediaService as never, r2StorageService as never, firebaseStorageService as never);
  });

  describe('verifyConnection', () => {
    it('verifies public R2 and private Firebase Storage connectivity', async () => {
      const previousR2Bucket = process.env.R2_BUCKET_NAME;
      const previousR2BaseUrl = process.env.R2_PUBLIC_BASE_URL;
      const previousFirebaseBucket = process.env.FIREBASE_STORAGE_BUCKET;
      process.env.R2_BUCKET_NAME = 'avijit-sahyog-public';
      process.env.R2_PUBLIC_BASE_URL = 'https://cdn.avijitsarthi.example';
      process.env.FIREBASE_STORAGE_BUCKET = 'avijit-sahyog.firebasestorage.app';

      await expect(controller.verifyConnection()).resolves.toEqual({
        status: 'ok',
        storage: 'cloudflare-r2',
        bucket: 'avijit-sahyog-public',
        privateStorage: 'firebase-storage',
        privateBucket: 'avijit-sahyog.firebasestorage.app',
      });
      expect(r2StorageService.verifyConnection).toHaveBeenCalledTimes(1);
      expect(firebaseStorageService.verifyConnection).toHaveBeenCalledTimes(1);

      if (previousR2Bucket === undefined) delete process.env.R2_BUCKET_NAME;
      else process.env.R2_BUCKET_NAME = previousR2Bucket;
      if (previousR2BaseUrl === undefined) delete process.env.R2_PUBLIC_BASE_URL;
      else process.env.R2_PUBLIC_BASE_URL = previousR2BaseUrl;
      if (previousFirebaseBucket === undefined) delete process.env.FIREBASE_STORAGE_BUCKET;
      else process.env.FIREBASE_STORAGE_BUCKET = previousFirebaseBucket;
    });

    it('rejects a missing or non-HTTPS R2 public base before checking either bucket', async () => {
      const previousBaseUrl = process.env.R2_PUBLIC_BASE_URL;
      delete process.env.R2_PUBLIC_BASE_URL;
      await expect(controller.verifyConnection()).rejects.toThrow('R2_PUBLIC_BASE_URL must be configured as an HTTPS URL.');
      expect(r2StorageService.verifyConnection).not.toHaveBeenCalled();
      expect(firebaseStorageService.verifyConnection).not.toHaveBeenCalled();
      process.env.R2_PUBLIC_BASE_URL = 'http://cdn.example';
      await expect(controller.verifyConnection()).rejects.toThrow('R2_PUBLIC_BASE_URL must be configured as an HTTPS URL.');
      if (previousBaseUrl === undefined) delete process.env.R2_PUBLIC_BASE_URL;
      else process.env.R2_PUBLIC_BASE_URL = previousBaseUrl;
    });

    it('propagates public R2 verification failures', async () => {
      const previousBaseUrl = process.env.R2_PUBLIC_BASE_URL;
      process.env.R2_PUBLIC_BASE_URL = 'https://cdn.avijitsarthi.example';
      r2StorageService.verifyConnection.mockRejectedValue(new Error('R2 unavailable'));
      await expect(controller.verifyConnection()).rejects.toThrow('R2 unavailable');
      if (previousBaseUrl === undefined) delete process.env.R2_PUBLIC_BASE_URL;
      else process.env.R2_PUBLIC_BASE_URL = previousBaseUrl;
    });

    it('propagates private Firebase Storage verification failures', async () => {
      const previousBaseUrl = process.env.R2_PUBLIC_BASE_URL;
      process.env.R2_PUBLIC_BASE_URL = 'https://cdn.avijitsarthi.example';
      firebaseStorageService.verifyConnection.mockRejectedValue(new Error('Firebase Storage unavailable'));
      await expect(controller.verifyConnection()).rejects.toThrow('Firebase Storage unavailable');
      if (previousBaseUrl === undefined) delete process.env.R2_PUBLIC_BASE_URL;
      else process.env.R2_PUBLIC_BASE_URL = previousBaseUrl;
    });
  });

  describe('uploadImage', () => {
    it('delegates uploaded files to MediaService', async () => {
      const file = {
        originalname: 'photo.jpg', mimetype: 'image/jpeg', size: 1024, buffer: Buffer.from('image'),
      } as Express.Multer.File;
      const uploadedMedia = { id: 'media-1', storageKey: 'uploads/media-1.webp' };
      mediaService.uploadImage.mockResolvedValue(uploadedMedia);
      await expect(controller.uploadImage(file)).resolves.toEqual(uploadedMedia);
      expect(mediaService.uploadImage).toHaveBeenCalledWith(file);
    });

    it('passes through validation failures', async () => {
      const file = {
        originalname: 'invalid.pdf', mimetype: 'application/pdf', size: 1024, buffer: Buffer.from('invalid'),
      } as Express.Multer.File;
      mediaService.uploadImage.mockRejectedValue(new Error('Only JPEG, PNG, and WebP images are allowed.'));
      await expect(controller.uploadImage(file)).rejects.toThrow('Only JPEG, PNG, and WebP images are allowed.');
    });
  });
});
