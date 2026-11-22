import { Module } from '@nestjs/common';
import { FirebaseModule } from '../firebase/firebase.module';
import { DonationsService } from './donations.service';
import { FirestoreDonationsService } from './firestore-donations.service';

@Module({
  imports: [FirebaseModule],
  providers: [
    FirestoreDonationsService,
    { provide: DonationsService, useExisting: FirestoreDonationsService },
  ],
})
export class DonationsModule {}
