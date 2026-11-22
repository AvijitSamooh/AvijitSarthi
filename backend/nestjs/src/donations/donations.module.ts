import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FirebaseModule } from '../firebase/firebase.module';
import { DonationsController } from './donations.controller';
import { DonationsService } from './donations.service';
import { FirestoreDonationsService } from './firestore-donations.service';

@Module({
  imports: [AuthModule, FirebaseModule],
  controllers: [DonationsController],
  providers: [
    FirestoreDonationsService,
    { provide: DonationsService, useExisting: FirestoreDonationsService },
  ],
  exports: [DonationsService],
})
export class DonationsModule {}
