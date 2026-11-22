import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Timestamp } from 'firebase-admin/firestore';
import { FirebaseService } from '../firebase/firebase.service';
import { FirebaseIdentity } from '../auth/auth.types';
import { FirestoreUsersService } from '../users/firestore-users.service';
import { CreateDonationDto } from './dto/create-donation.dto';

const RECEIPT_LANGUAGES = new Set(['en', 'hi', 'mr', 'gu']);

@Injectable()
export class FirestoreDonationsService {
  constructor(
    private readonly firebase: FirebaseService,
    private readonly users: FirestoreUsersService,
  ) {}

  /**
   * Internal donation-domain entry point retained for migration/domain tests.
   * Public clients cannot call it; authenticated payment orchestration should
   * use createForDonor so every donor-owned record has a server-resolved owner.
   */
  async create(input: CreateDonationDto) {
    return this.createInternal(input);
  }

  async createForDonor(identity: FirebaseIdentity, input: CreateDonationDto) {
    const user = await this.users.upsertFromIdentity(identity);
    return this.createInternal(input, user.id);
  }

  private async createInternal(input: CreateDonationDto, donorUserId?: string) {
    const amount = this.cents(input.amount, 'Donation amount');
    const currency = input.currency ?? 'INR';
    if (currency !== 'INR') throw new BadRequestException('Only INR is currently supported');
    if (amount <= 0n) throw new BadRequestException('Donation amount must be greater than zero');
    if (!Array.isArray(input.allocations) || input.allocations.length === 0) {
      throw new BadRequestException('Donation must be allocated to at least one cause');
    }

    const allocations = input.allocations.map((allocation) => ({
      id: randomUUID(),
      causeId: allocation.causeId,
      amount: this.cents(allocation.amount, 'Allocation amount'),
      createdAt: Timestamp.now(),
    }));

    if (allocations.some((allocation) => allocation.amount <= 0n)) {
      throw new BadRequestException('Allocation amounts must be greater than zero');
    }

    const uniqueCauseIds = new Set(allocations.map((allocation) => allocation.causeId));
    if (uniqueCauseIds.size !== allocations.length) {
      throw new BadRequestException('A cause can only appear once in a donation allocation');
    }

    const allocationTotal = allocations.reduce((sum, allocation) => sum + allocation.amount, 0n);
    if (allocationTotal !== amount) {
      throw new BadRequestException('Allocation total must equal the donation amount');
    }

    const refs = [...uniqueCauseIds].map((id) => this.firebase.db.collection('causes').doc(id));
    const donationId = randomUUID();
    const now = Timestamp.now();

    return this.firebase.db.runTransaction(async (transaction) => {
      const causes = await transaction.getAll(...refs);
      if (
        causes.length !== refs.length ||
        causes.some((snapshot) => !snapshot.exists || snapshot.data()?.isActive !== true)
      ) {
        throw new BadRequestException('Donation allocations must reference active causes');
      }

      const document = {
        id: donationId,
        ...(donorUserId ? { donorUserId } : {}),
        amount: this.formatCents(amount),
        currency,
        status: 'PENDING',
        allocations: allocations.map((allocation) => ({
          id: allocation.id,
          causeId: allocation.causeId,
          organisationId: null,
          amount: this.formatCents(allocation.amount),
          createdAt: allocation.createdAt,
        })),
        createdAt: now,
        updatedAt: now,
      };

      transaction.set(this.firebase.db.collection('donations').doc(donationId), document);
      return this.toDonationResponse(donationId, document);
    });
  }

  async listMine(identity: FirebaseIdentity) {
    const user = await this.users.upsertFromIdentity(identity);
    const snapshot = await this.firebase.db.collection('donations')
      .where('donorUserId', '==', user.id)
      .get();
    const items = snapshot.docs.map((doc) => this.toDonationResponse(doc.id, doc.data()));
    items.sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime());
    return items;
  }

  async findMine(identity: FirebaseIdentity, id: string) {
    const user = await this.users.upsertFromIdentity(identity);
    const snapshot = await this.firebase.db.collection('donations').doc(id).get();
    if (!snapshot.exists || snapshot.data()?.donorUserId !== user.id) {
      throw new NotFoundException('Donation not found.');
    }
    return this.toDonationResponse(snapshot.id, snapshot.data()!);
  }

  async issueReceipt(identity: FirebaseIdentity, donationId: string, language?: string) {
    const user = await this.users.upsertFromIdentity(identity);
    const donationRef = this.firebase.db.collection('donations').doc(donationId);
    const receiptRef = this.firebase.db.collection('receipts').doc(donationId);

    return this.firebase.db.runTransaction(async (transaction) => {
      const [donationSnapshot, receiptSnapshot] = await Promise.all([
        transaction.get(donationRef),
        transaction.get(receiptRef),
      ]);
      if (!donationSnapshot.exists || donationSnapshot.data()?.donorUserId !== user.id) {
        throw new NotFoundException('Donation not found.');
      }
      if (receiptSnapshot.exists) {
        const existing = receiptSnapshot.data()!;
        if (existing.donorUserId !== user.id) throw new NotFoundException('Receipt not found.');
        return this.toReceiptResponse(receiptSnapshot.id, existing);
      }

      const donation = donationSnapshot.data()!;
      if (donation.status !== 'SUCCESS') {
        throw new BadRequestException('A receipt is available only after a donation is verified as successful.');
      }

      const createdAt = this.toDate(donation.createdAt);
      const generatedAt = Timestamp.now();
      const receipt = {
        id: donationId,
        donationId,
        donorUserId: user.id,
        receiptNumber: this.receiptNumber(donationId, createdAt),
        amount: String(donation.amount),
        currency: String(donation.currency ?? 'INR'),
        language: this.receiptLanguage(language),
        allocations: (Array.isArray(donation.allocations) ? donation.allocations : []).map((item: any) => ({
          causeId: String(item.causeId),
          amount: String(item.amount),
        })),
        donationCreatedAt: donation.createdAt,
        issuedAt: generatedAt,
      };
      transaction.create(receiptRef, receipt);
      return this.toReceiptResponse(donationId, receipt);
    });
  }

  async findReceipt(identity: FirebaseIdentity, donationId: string) {
    const user = await this.users.upsertFromIdentity(identity);
    const [donationSnapshot, receiptSnapshot] = await Promise.all([
      this.firebase.db.collection('donations').doc(donationId).get(),
      this.firebase.db.collection('receipts').doc(donationId).get(),
    ]);
    if (!donationSnapshot.exists || donationSnapshot.data()?.donorUserId !== user.id) {
      throw new NotFoundException('Donation not found.');
    }
    if (!receiptSnapshot.exists || receiptSnapshot.data()?.donorUserId !== user.id) {
      throw new NotFoundException('Receipt not found.');
    }
    return this.toReceiptResponse(receiptSnapshot.id, receiptSnapshot.data()!);
  }

  async findOne(id: string) {
    const snapshot = await this.firebase.db.collection('donations').doc(id).get();
    if (!snapshot.exists) throw new NotFoundException(`Donation '${id}' not found`);

    const donation = snapshot.data()!;
    const allocations = Array.isArray(donation.allocations) ? donation.allocations : [];
    const ids = [...new Set(allocations.map((allocation: any) => allocation.causeId).filter(Boolean))];
    const causeSnapshots = await Promise.all(
      ids.map((causeId) => this.firebase.db.collection('causes').doc(String(causeId)).get()),
    );
    const causeById = new Map(
      causeSnapshots.filter((item) => item.exists).map((item) => [item.id, item.data()]),
    );

    return {
      ...donation,
      createdAt: this.toDate(donation.createdAt),
      updatedAt: this.toDate(donation.updatedAt),
      allocations: allocations.map((allocation: any) => ({
        ...allocation,
        createdAt: this.toDate(allocation.createdAt),
        amount: String(allocation.amount),
        cause: causeById.has(allocation.causeId)
          ? { id: allocation.causeId, slug: causeById.get(allocation.causeId)?.slug }
          : null,
        organisation: null,
      })),
    };
  }

  private toDonationResponse(id: string, donation: any) {
    const allocations = Array.isArray(donation.allocations) ? donation.allocations : [];
    return {
      id,
      amount: String(donation.amount),
      currency: String(donation.currency ?? 'INR'),
      status: String(donation.status ?? 'PENDING'),
      createdAt: this.toDate(donation.createdAt),
      updatedAt: this.toDate(donation.updatedAt ?? donation.createdAt),
      allocations: allocations.map((allocation: any) => ({
        id: allocation.id ? String(allocation.id) : undefined,
        causeId: String(allocation.causeId),
        amount: String(allocation.amount),
        createdAt: this.toDate(allocation.createdAt ?? donation.createdAt),
      })),
    };
  }

  private toReceiptResponse(id: string, receipt: any) {
    return {
      id,
      donationId: String(receipt.donationId),
      receiptNumber: String(receipt.receiptNumber),
      amount: String(receipt.amount),
      currency: String(receipt.currency ?? 'INR'),
      language: this.receiptLanguage(receipt.language),
      allocations: Array.isArray(receipt.allocations) ? receipt.allocations : [],
      donationCreatedAt: this.toDate(receipt.donationCreatedAt),
      issuedAt: this.toDate(receipt.issuedAt),
    };
  }

  private receiptNumber(donationId: string, createdAt: Date) {
    const suffix = createHash('sha256').update(donationId).digest('hex').slice(0, 10).toUpperCase();
    return `AS-${createdAt.getUTCFullYear()}-${suffix}`;
  }

  private receiptLanguage(language?: unknown) {
    const normalized = typeof language === 'string' ? language.trim().toLowerCase() : undefined;
    return normalized && RECEIPT_LANGUAGES.has(normalized) ? normalized : 'en';
  }

  private cents(value: string, fieldName: string): bigint {
    const normalized = String(value).trim();
    if (!/^\d+(?:\.\d{1,2})?$/.test(normalized)) {
      throw new BadRequestException(`${fieldName} must be a valid decimal amount`);
    }
    const [whole, fraction = ''] = normalized.split('.');
    return BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
  }

  private formatCents(value: bigint) {
    return `${value / 100n}.${(value % 100n).toString().padStart(2, '0')}`;
  }

  private toDate(value: unknown): Date {
    if (value instanceof Timestamp) return value.toDate();
    if (value instanceof Date) return value;
    if (value && typeof value === 'object' && 'toDate' in value && typeof (value as any).toDate === 'function') {
      return (value as any).toDate();
    }
    return new Date(String(value));
  }
}
