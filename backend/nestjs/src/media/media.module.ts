import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FirebaseModule } from '../firebase/firebase.module';
import { MediaController, UserMediaController } from './media.controller';
import { MediaService } from './media.service';
import { FirebaseStorageService } from './firebase-storage.service';
import { R2StorageService } from './r2-storage.service';
import { FirestoreMediaService } from './firestore-media.service';

@Module({
  imports: [AuthModule, FirebaseModule],
  controllers: [MediaController, UserMediaController],
  providers: [MediaService, FirebaseStorageService, R2StorageService, FirestoreMediaService],
  exports: [MediaService, FirebaseStorageService, R2StorageService, FirestoreMediaService],
})
export class MediaModule {}
