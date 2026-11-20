import { BadRequestException, ConflictException } from '@nestjs/common';
import { Timestamp } from 'firebase-admin/firestore';
import { FirestoreUsersService } from './firestore-users.service';

describe('FirestoreUsersService city administrator assignments', () => {
  const actor = { id: 'root', role: 'SUPER_ADMIN', cityIds: [] } as any;
  const target = {
    id: 'target', firebaseUid: 'firebase-target', email: 'city@example.com',
    displayName: 'City Admin', photoUrl: null, role: 'USER', cityIds: [],
    preferredLanguage: null, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), searchTokens: [],
  };
  const setup = () => {
    const update = jest.fn();
    const set = jest.fn();
    const transaction = {
      get: jest.fn().mockResolvedValue({ exists: true, id: target.id, data: () => ({ ...target }), ref: {} }),
      update, set,
    };
    const db: any = {
      collection: jest.fn((name: string) => ({
        doc: jest.fn((id: string) => ({ id, create: jest.fn(), update, delete: jest.fn() })),
      })),
      runTransaction: jest.fn(async (callback: any) => callback(transaction)),
    };
    const service = new FirestoreUsersService({ db } as any);
    jest.spyOn(service, 'getByFirebaseUid').mockResolvedValue(actor);
    return { service, transaction, update, set };
  };

  it('assigns CITY_ADMIN and city IDs with a role audit in the same transaction', async () => {
    const { service, transaction, update, set } = setup();
    const result = await service.changeRole('target', 'root-uid', 'CITY_ADMIN', ['pune', 'mumbai', 'pune']);
    expect(result.role).toBe('CITY_ADMIN');
    expect(result.cityIds).toEqual(['pune', 'mumbai']);
    expect(update).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({
      role: 'CITY_ADMIN', cityIds: ['pune', 'mumbai'],
    }));
    expect(set).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({
      action: 'USER_ROLE_CHANGED', fromRole: 'USER', toRole: 'CITY_ADMIN',
      metadata: expect.objectContaining({ reason: 'city_admin_assignment', cityIds: ['pune', 'mumbai'] }),
    }));
    expect(transaction.get).toHaveBeenCalledTimes(1);
  });

  it('requires at least one city for CITY_ADMIN and disallows city IDs for other roles', async () => {
    const { service } = setup();
    await expect(service.changeRole('target', 'root-uid', 'CITY_ADMIN', [])).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.changeRole('target', 'root-uid', 'ADMIN', ['pune'])).rejects.toBeInstanceOf(BadRequestException);
  });

  it('allows updating assignments for an existing City Admin and rejects an identical assignment', async () => {
    const { service } = setup();
    target.role = 'CITY_ADMIN';
    target.cityIds = ['pune'];
    const changed = await service.changeRole('target', 'root-uid', 'CITY_ADMIN', ['mumbai']);
    expect(changed.cityIds).toEqual(['mumbai']);
    await expect(service.changeRole('target', 'root-uid', 'CITY_ADMIN', ['pune'])).rejects.toBeInstanceOf(ConflictException);
    target.role = 'USER';
    target.cityIds = [];
  });

  it('prevents non-super-admin actors from assigning city administrators', async () => {
    const { service } = setup();
    jest.spyOn(service, 'getByFirebaseUid').mockResolvedValue({ ...actor, role: 'ADMIN' } as any);
    await expect(service.changeRole('target', 'admin-uid', 'CITY_ADMIN', ['pune'])).rejects.toBeInstanceOf(BadRequestException);
  });
});
