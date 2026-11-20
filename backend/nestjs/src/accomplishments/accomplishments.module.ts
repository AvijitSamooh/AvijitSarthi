import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FirebaseModule } from '../firebase/firebase.module';
import { CityAdminGuard } from '../auth/city-admin.guard';
import { CityContentService } from '../activities/city-content.service';
import { AdminAccomplishmentsController, AccomplishmentsController } from './accomplishments.controller';
@Module({
  imports: [AuthModule, FirebaseModule],
  controllers: [AdminAccomplishmentsController, AccomplishmentsController],
  providers: [CityAdminGuard, CityContentService],
})
export class AccomplishmentsModule {}
