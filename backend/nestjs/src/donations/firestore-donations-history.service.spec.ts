import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Timestamp } from 'firebase-admin/firestore';
import { FirestoreDonationsService } from './firestore-donations.service';

describe('FirestoreDonationsService donor history and receipts', () => {
  const identity = { uid: 'firebase-user-1', email: 'donor@example.com' };

  function makeService() {
    const store = new Map<string, any>();
    const key = (collection: string, id: string) => `${collection}/${id}`;
    const snapshot = (collection: string, id: string) => {
      const value = store.get(key(collection, id));
      return { id, exists: value !== undefined, data: () => value };
    };
    const reference = (collection: string, id: string) => ({
      id,
      collection,
      get: jest.fn(async () => snapshot(collection, id)),
    });
    const collections = new Map<string, any>();
    const db: any = {
      collection: jest.fn((name: string) => {
        if (!collections.has(name)) {
          collections.set(name, {
            doc: jest.fn((id: string) => reference(name, id)),
            where: jest.fn((field: string, operator: string, value: unknown) => ({
              get: jest.fn(async () => ({
                docs: [...store.entries()]
                  .filter(([path, data]) => path.startsWith(`${name}/`) && operator === '==' && data[field] === value)
                  .map(([path, data]) => ({ id: path.slice(name.length + 1), data: () => data })),
              })),
            })),
          });
        }
        return collections.get(name);
      }),
      runTransaction: jest.fn(async (callback: (transaction: any) => unknown) => callback({
        get: jest.fn(async (ref: any) => snapshot(ref.collection, ref.id)),
        getAll: jest.fn(async (...refs: any[]) => refs.map((ref) => snapshot(ref.collection, ref.id))),
        set: jest.fn((ref: any, data: any) => store.set(key(ref.collection, ref.id), data)),
        create: jest.fn((ref: any, data: any) => {
          const path = key(ref.collection, ref.id);
          if (store.has(path)) throw new Error('Document already exists');
          store.set(path, data);
        }),
      })),
    };
    const users = {
      upsertFromIdentity: jest.fn().mockResolvedValue({ id: 'user-1' }),
    };
    return {
      service: new FirestoreDonationsService({ db } as any, users as any),
      store,
      key,
      users,
      db,
    };
  }

  it('creates donor-owned records from a verified Firebase identity', async () => {
    const { service, store } = makeService();
    const result = await service.createForDonor(identity, {
      amount: '100.00',
      allocations: [{ causeId: 'cause-1', amount: '100.00' }],
    } as any);

    const saved = store.get(`donations/${result.id}`);
    expect(saved.donorUserId).toBe('user-1');
    expect(saved.status).toBe('PENDING');
    expect(result.amount).toBe('100.00');
  });

  it('lists only the authenticated donor records in newest-first order', async () => {
    const { service, store } = makeService();
    store.set('donations/older', {
      amount: '10.00', status: 'SUCCESS', donorUserId: 'user-1',
      createdAt: Timestamp.fromDate(new Date('2025-01-01T00:00:00Z')),
      allocations: [{ causeId: 'cause-1', amount: '10.00' }],
    });
    store.set('donations/newer', {
      amount: '20.00', status: 'PENDING', donorUserId: 'user-1',
      createdAt: Timestamp.fromDate(new Date('2025-02-01T00:00:00Z')),
      allocations: [{ causeId: 'cause-2', amount: '20.00' }],
    });
    store.set('donations/other-user', {
      amount: '99.00', status: 'SUCCESS', donorUserId: 'user-2',
      createdAt: Timestamp.fromDate(new Date('2025-03-01T00:00:00Z')),
      allocations: [],
    });

    const result = await service.listMine(identity);
    expect(result.map((item) => item.id)).toEqual(['newer', 'older']);
    expect(result[0].allocations[0].causeId).toBe('cause-2');
  });

  it('hides another donor donation behind a not-found response', async () => {
    const { service, store } = makeService();
    store.set('donations/private', {
      donorUserId: 'user-2', amount: '10.00', status: 'SUCCESS',
      createdAt: Timestamp.now(), allocations: [],
    });
    await expect(service.findMine(identity, 'private')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('issues one deterministic receipt only after payment verification', async () => {
    const { service, store } = makeService();
    const createdAt = Timestamp.fromDate(new Date('2026-03-04T12:00:00Z'));
    store.set('donations/paid-donation', {
      id: 'paid-donation', donorUserId: 'user-1', amount: '125.50', currency: 'INR',
      status: 'SUCCESS', createdAt, updatedAt: createdAt,
      allocations: [
        { causeId: 'jeev-daya', amount: '100.00' },
        { causeId: 'education', amount: '25.50' },
      ],
    });

    const first = await service.issueReceipt(identity, 'paid-donation', 'hi');
    const second = await service.issueReceipt(identity, 'paid-donation', 'gu');

    expect(first.receiptNumber).toMatch(/^AS-2026-[A-F0-9]{10}$/);
    expect(second.receiptNumber).toBe(first.receiptNumber);
    expect(second.language).toBe('hi');
    expect(second.allocations).toEqual([
      { causeId: 'jeev-daya', amount: '100.00' },
      { causeId: 'education', amount: '25.50' },
    ]);
    expect(store.get('receipts/paid-donation')).toMatchObject({
      donorUserId: 'user-1',
      donationId: 'paid-donation',
      language: 'hi',
    });
  });

  it('rejects receipt issuance for pending or another donor donation', async () => {
    const { service, store } = makeService();
    store.set('donations/pending', {
      donorUserId: 'user-1', amount: '10.00', status: 'PENDING',
      createdAt: Timestamp.now(), allocations: [],
    });
    store.set('donations/private', {
      donorUserId: 'user-2', amount: '10.00', status: 'SUCCESS',
      createdAt: Timestamp.now(), allocations: [],
    });

    await expect(service.issueReceipt(identity, 'pending')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.issueReceipt(identity, 'private')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('returns only an already issued receipt to its owning donor', async () => {
    const { service, store } = makeService();
    const issuedAt = Timestamp.now();
    store.set('donations/paid', {
      donorUserId: 'user-1', amount: '10.00', status: 'SUCCESS',
      createdAt: issuedAt, allocations: [],
    });
    store.set('receipts/paid', {
      donorUserId: 'user-1', donationId: 'paid', receiptNumber: 'AS-2026-ABCDEF1234',
      amount: '10.00', currency: 'INR', language: 'en', allocations: [],
      donationCreatedAt: issuedAt, issuedAt,
    });

    await expect(service.findReceipt(identity, 'paid')).resolves.toMatchObject({
      donationId: 'paid', receiptNumber: 'AS-2026-ABCDEF1234',
    });
    await expect(service.findReceipt({ uid: 'other' }, 'paid')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('falls back to English for unsupported receipt languages', async () => {
    const { service, store } = makeService();
    const createdAt = Timestamp.now();
    store.set('donations/paid', {
      donorUserId: 'user-1', amount: '1.00', currency: 'INR', status: 'SUCCESS',
      createdAt, allocations: [],
    });
    const receipt = await service.issueReceipt(identity, 'paid', 'fr');
    expect(receipt.language).toBe('en');
  });
});
