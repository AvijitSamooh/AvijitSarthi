import { NotFoundException } from '@nestjs/common';
import { FirestoreBeneficiariesService } from './firestore-beneficiaries.service';

describe('FirestoreBeneficiariesService', () => {
  const item: any = {
    id: 'b1',
    sourceApplicationId: null,
    name: 'Alice',
    photoUrl: null,
    story: 'story',
    supportedYear: 2026,
    contributionAmount: '1000',
    causeId: 'c1',
    organisationId: 'o1',
    isActive: true,
    displayOrder: 1,
    media: [],
  };
  const mediaService = {
    getReadUrl: jest.fn(async (media: any) => {
      if (media.storageProvider === 'R2') {
        return `${process.env.R2_PUBLIC_BASE_URL?.replace(/\/$/, '')}/${media.storageKey}`;
      }
      return `https://signed.example/${media.storageKey}`;
    }),
  };

  function db(causeData: any = { id: 'c1', slug: 'cause', isActive: true, childIds: [] }) {
    const ref: any = {
      id: 'b1',
      get: jest.fn().mockResolvedValue({ exists: true, data: () => item }),
      set: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    };
    const col: any = {
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ docs: [{ id: 'b1', data: () => item }] }),
      doc: jest.fn(() => ref),
    };
    const d: any = {
      collection: jest.fn((name) => {
        if (name === 'beneficiaries') return col;
        return {
          doc: jest.fn((id) => ({
            id,
            get: jest.fn().mockResolvedValue({
              exists: true,
              data: () => name === 'causes'
                ? causeData
                : { id, slug: id, isActive: true, storageKey: 'x', storageProvider: 'R2', mimeType: 'image/jpeg', width: 10, height: 10 },
            }),
          })),
        };
      }),
      getAll: jest.fn(async (...refs: any[]) => refs.map((ref: any) => ({
        id: ref.id,
        exists: true,
        data: () => ({ id: ref.id, slug: ref.id, isActive: true, storageKey: 'x', storageProvider: 'R2', mimeType: 'image/jpeg', width: 10, height: 10 }),
      }))),
    };
    return { d, ref };
  }

  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.R2_PUBLIC_BASE_URL;
  });

  it('covers admin CRUD and public filtering', async () => {
    const { d, ref } = db();
    const service = new FirestoreBeneficiariesService({ db: d } as any, mediaService as any);
    expect((await service.create({ name: 'Bob', causeId: 'c1' })).name).toBe('Bob');
    await service.findAllForAdmin();
    await service.findOneForAdmin('b1');
    await service.update('b1', { name: 'A' });
    await service.setActive('b1', true);
    await service.remove('b1');
    await service.removeBeneficiary('b1');
    expect(ref.delete).toHaveBeenCalled();
    expect((await service.findAll({ search: 'ali', causeId: 'c1', year: 2026, sort: 'name_asc' }))[0].name).toBe('Alice');
  });

  it('rejects inactive and parent causes for new beneficiaries', async () => {
    const parentDb = db({ id: 'c1', slug: 'education', isActive: true, childIds: ['child-1'] });
    const parentService = new FirestoreBeneficiariesService({ db: parentDb.d } as any, mediaService as any);
    await expect(parentService.create({ name: 'Bob', causeId: 'c1' }))
      .rejects.toThrow('leaf cause');

    const inactiveDb = db({ id: 'c1', slug: 'medical', isActive: false, childIds: [] });
    const inactiveService = new FirestoreBeneficiariesService({ db: inactiveDb.d } as any, mediaService as any);
    await expect(inactiveService.create({ name: 'Bob', causeId: 'c1' }))
      .rejects.toThrow('active cause');
  });

  it('rejects publishing a beneficiary under a parent cause', async () => {
    const { d, ref } = db({ id: 'c1', slug: 'education', isActive: true, childIds: ['child-1'] });
    const service = new FirestoreBeneficiariesService({ db: d } as any, mediaService as any);
    await expect(service.syncBeneficiary({
      id: 'b2',
      sourceApplicationId: 'application-1',
      name: 'Student',
      photoUrl: null,
      story: null,
      supportedYear: 2026,
      contributionAmount: '0',
      causeId: 'c1',
      organisationId: null,
      isActive: true,
      displayOrder: 0,
      media: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    })).rejects.toThrow('leaf cause');
    expect(ref.set).not.toHaveBeenCalled();
  });

  it('rejects changing or reactivating a beneficiary with a parent cause', async () => {
    const { d, ref } = db({ id: 'c1', slug: 'education', isActive: true, childIds: ['child-1'] });
    const service = new FirestoreBeneficiariesService({ db: d } as any, mediaService as any);
    await expect(service.update('b1', { causeId: 'c1' }))
      .rejects.toThrow('leaf cause');
    await expect(service.update('b1', { story: 'updated story' }))
      .rejects.toThrow('leaf cause');
    await expect(service.setActive('b1', true))
      .rejects.toThrow('leaf cause');
    expect(ref.update).not.toHaveBeenCalled();
  });

  it('covers sorting and provider-aware media helpers', async () => {
    const { d } = db();
    const service: any = new FirestoreBeneficiariesService({ db: d } as any, mediaService as any);
    const a = { ...item, name: 'A', contributionAmount: '20', supportedYear: 2025, displayOrder: 1 };
    const b = { ...item, name: 'B', contributionAmount: '10', supportedYear: 2026, displayOrder: 2 };
    for (const sort of ['name_asc', 'amount_desc', 'amount_asc', 'year_asc', undefined]) service.compare(a, b, sort);

    process.env.R2_PUBLIC_BASE_URL = 'https://cdn/';
    const publicMedia = { id: 'm1', storageKey: 'a', storageProvider: 'R2', mimeType: 'image/jpeg', width: 1, height: 1 };
    await expect(service.mediaUrl(publicMedia)).resolves.toBe('https://cdn/a');
    await expect(service.primaryMedia([{ purpose: 'PROFILE', isPrimary: true, media: publicMedia }], 'PROFILE')).resolves.toMatchObject({ url: 'https://cdn/a' });
    await expect(service.galleryMedia([{ purpose: 'GALLERY', displayOrder: 1, media: publicMedia }], 'GALLERY')).resolves.toHaveLength(1);
  });

  it('rejects missing beneficiary', async () => {
    const { d } = db();
    d.collection.mockImplementation(() => ({ doc: jest.fn(() => ({ get: jest.fn().mockResolvedValue({ exists: false }) })) }));
    const service = new FirestoreBeneficiariesService({ db: d } as any, mediaService as any);
    await expect(service.findOne('x')).rejects.toBeInstanceOf(NotFoundException);
  });
});
