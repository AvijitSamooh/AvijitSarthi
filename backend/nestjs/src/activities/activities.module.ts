import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FirebaseModule } from '../firebase/firebase.module';
import { CityAdminGuard } from '../auth/city-admin.guard';
import { CityContentService } from './city-content.service';
import { AdminActivitiesController, ActivitiesController } from './activities.controller';
@Module({
  imports: [AuthModule, FirebaseModule],
  controllers: [AdminActivitiesController, ActivitiesController],
  providers: [CityContentService, CityAdminGuard],
  exports: [CityContentService],
})
export class ActivitiesModule {}
