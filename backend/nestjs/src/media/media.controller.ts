import {
  Controller, Delete, Get, Post, Param, UploadedFile, Req, UseGuards, UseInterceptors, InternalServerErrorException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AdminGuard } from '../auth/admin.guard';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AuthenticatedRequest } from '../auth/auth.types';
import { AuthService } from '../auth/auth.service';
import { Request } from 'express';
import { MediaService } from './media.service';
import { R2StorageService } from './r2-storage.service';
import { FirebaseStorageService } from './firebase-storage.service';

@Controller('admin/media')
@UseGuards(AdminGuard)
export class MediaController {
  constructor(
    private readonly mediaService: MediaService,
    private readonly storageService: R2StorageService,
    private readonly privateStorageService: FirebaseStorageService,
  ) {}

  @Get('verify')
  async verifyConnection() {
    const publicBaseUrl = process.env.R2_PUBLIC_BASE_URL?.trim();
    if (!publicBaseUrl || !publicBaseUrl.startsWith('https://')) {
      throw new InternalServerErrorException('R2_PUBLIC_BASE_URL must be configured as an HTTPS URL.');
    }
    await Promise.all([
      this.storageService.verifyConnection(),
      this.privateStorageService.verifyConnection(),
    ]);
    return {
      status: 'ok',
      storage: 'cloudflare-r2',
      bucket: process.env.R2_BUCKET_NAME,
      privateStorage: 'firebase-storage',
      privateBucket: process.env.FIREBASE_STORAGE_BUCKET,
    };
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 },
  }))
  async uploadImage(@UploadedFile() file: Express.Multer.File) {
    return this.mediaService.uploadImage(file);
  }
}

@Controller('media')
@UseGuards(FirebaseAuthGuard)
export class UserMediaController {
  constructor(
    private readonly mediaService: MediaService,
    private readonly authService: AuthService,
  ) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 },
  }))
  async uploadUserImage(@Req() req: Request & AuthenticatedRequest, @UploadedFile() file: Express.Multer.File) {
    const user = await this.authService.getCurrentUser(req.user);
    return this.mediaService.uploadImage(file, 'applications', user.id);
  }

  @Delete(':id')
  async deleteUserImage(@Req() req: Request & AuthenticatedRequest, @Param('id') id: string) {
    const user = await this.authService.getCurrentUser(req.user);
    return this.mediaService.deleteUserImage(id, user.id);
  }
}
