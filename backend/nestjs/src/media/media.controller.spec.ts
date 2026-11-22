import { MediaController } from './media.controller';

describe('MediaController', () => {
  let controller: MediaController;
  let mediaService: { uploadImage: jest.Mock };
  let storageService: { verifyConnection: jest.Mock };

  beforeEach(() => {
    mediaService = { uploadImage: jest.fn() };
    storageService = { verifyConnection: jest.fn() };
    controller = new MediaController(mediaService as never, storageService as never);
  });

  describe('verifyConnection', () => {
    it('verifies the R2 bucket and public HTTPS base URL', async () => {
      const previousBucket = process.env.R2_BUCKET_NAME;
      const previousBaseUrl = process.env.R2_PUBLIC_BASE_URL;
      process.env.R2_BUCKET_NAME = 'avijit-sahyog-public';
      process.env.R2_PUBLIC_BASE_URL = 'https://cdn.avijitsarthi.example';
      await expect(controller.verifyConnection()).resolves.toEqual({
        status: 'ok',
        storage: 'cloudflare-r2',
        bucket: 'avijit-sahyog-public',
      });
      expect(storageService.verifyConnection).toHaveBeenCalledTimes(1);
      if (previousBucket === undefined) delete process.env.R2_BUCKET_NAME;
      else process.env.R2_BUCKET_NAME = previousBucket;
      if (previousBaseUrl === undefined) delete process.env.R2_PUBLIC_BASE_URL;
      else process.env.R2_PUBLIC_BASE_URL = previousBaseUrl;
    });

    it('rejects a missing or non-HTTPS public base before checking the bucket', async () => {
      const previousBaseUrl = process.env.R2_PUBLIC_BASE_URL;
      delete process.env.R2_PUBLIC_BASE_URL;
      await expect(controller.verifyConnection()).rejects.toThrow('R2_PUBLIC_BASE_URL must be configured as an HTTPS URL.');
      expect(storageService.verifyConnection).not.toHaveBeenCalled();
      process.env.R2_PUBLIC_BASE_URL = 'http://cdn.example';
      await expect(controller.verifyConnection()).rejects.toThrow('R2_PUBLIC_BASE_URL must be configured as an HTTPS URL.');
      if (previousBaseUrl === undefined) delete process.env.R2_PUBLIC_BASE_URL;
      else process.env.R2_PUBLIC_BASE_URL = previousBaseUrl;
    });

    it('propagates storage verification failures', async () => {
      storageService.verifyConnection.mockRejectedValue(new Error('Storage unavailable'));
      await expect(controller.verifyConnection()).rejects.toThrow('Storage unavailable');
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
