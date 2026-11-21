import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { CityContentService } from './city-content.service';

describe('CityContentService business rules', () => {
  const makeHarness = (initial: Record<string, any> = {}) => {
    const docs = new Map(Object.entries(initial));
    const ref = (collection: string, id: string) => ({
      id,
      get: jest.fn(async () => ({ exists: docs.has(id), data: () => docs.get(id) })),
      create: jest.fn(async (value: any) => { if (docs.has(id)) throw new Error('already exists'); docs.set(id, value); }),
    });
    const db: any = {
      collection: jest.fn((collection: string) => ({
        doc: (id: string) => {
          const r = ref(collection, id);
          return {
            ...r,
            update: jest.fn(async (patch: any) => docs.set(id, { ...docs.get(id), ...patch })),
            delete: jest.fn(async () => docs.delete(id)),
          };
        },
        get: jest.fn(async () => ({ docs: [...docs.entries()].map(([id, data]) => ({ id, data: () => data })) })),
      })),
      getAll: jest.fn(async (...refs: any[]) => refs.map((r) => ({ exists: r.id === 'org-1' }))),
      runTransaction: jest.fn(async (callback: any) => callback({
        get: async (r: any) => ({ exists: docs.has(r.id), data: () => docs.get(r.id) }),
        update: (r: any, patch: any) => docs.set(r.id, { ...docs.get(r.id), ...patch }),
        delete: (r: any) => docs.delete(r.id),
      })),
    };
    return { service: new CityContentService({ db } as any), docs, db };
  };
  const cityAdmin: any = { id: 'u-city', role: 'CITY_ADMIN', cityIds: ['pune'] };
  const superAdmin: any = { id: 'u-root', role: 'SUPER_ADMIN', cityIds: [] };

  it('creates draft activities linked to existing organisations and lists only published public records', async () => {
    const { service, docs } = makeHarness();
    const created = await service.create('activities', {
      cityId: 'pune', title: 'Health camp', description: 'Free checkups',
      startsAt: '2026-12-01T10:00:00.000Z', organisationIds: ['org-1'],
    }, cityAdmin);
    expect(created.status).toBe('DRAFT');
    expect(created.organisationIds).toEqual(['org-1']);
    expect(docs.get(created.id)).toEqual(created);
    await service.update('activities', created.id, { status: 'PUBLISHED' }, cityAdmin);
    expect((await service.list('activities')).map((x) => x.id)).toContain(created.id);
  });

  it('rejects content for a city outside the localized catalogue', async () => {
    const { service, docs } = makeHarness();
    await expect(service.create('activities', {
      cityId: 'unknown-city', title: 'x', description: 'y', startsAt: '2026-12-01T10:00:00Z',
    }, superAdmin)).rejects.toBeInstanceOf(BadRequestException);
    expect(docs.size).toBe(0);
  });

  it('keeps draft and archived records out of public city lists and detail routes', async () => {
    const { service } = makeHarness({
      draft: { id: 'draft', cityId: 'pune', status: 'DRAFT', startsAt: '2026-12-01T10:00:00Z' },
      archived: { id: 'archived', cityId: 'pune', status: 'ARCHIVED', startsAt: '2026-12-02T10:00:00Z' },
      published: { id: 'published', cityId: 'pune', status: 'PUBLISHED', startsAt: '2026-12-03T10:00:00Z', organisationIds: ['org-1'] },
      otherCity: { id: 'otherCity', cityId: 'mumbai', status: 'PUBLISHED', startsAt: '2026-12-04T10:00:00Z' },
    });

    expect((await service.list('activities')).map((item) => item.id)).toEqual(['otherCity', 'published']);
    expect((await service.list('activities', undefined, 'pune')).map((item) => item.id)).toEqual(['published']);
    expect((await service.get('activities', 'published')).organisationIds).toEqual(['org-1']);
    await expect(service.get('activities', 'draft')).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.get('activities', 'archived')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('prevents a city admin creating or reading content outside assigned cities', async () => {
    const { service } = makeHarness({ 'outside-1': { id: 'outside-1', cityId: 'mumbai', status: 'PUBLISHED' } });
    await expect(service.create('activities', {
      cityId: 'mumbai', title: 'x', description: 'y', startsAt: '2026-12-01T10:00:00Z',
    }, cityAdmin)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.get('activities', 'outside-1', cityAdmin)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.update('activities', 'outside-1', { title: 'Changed' }, cityAdmin)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.remove('activities', 'outside-1', cityAdmin)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('validates end-before-start and unknown affiliate references without creating partial records', async () => {
    const { service, docs, db } = makeHarness();
    await expect(service.create('activities', {
      cityId: 'pune', title: 'x', description: 'y', startsAt: '2026-12-02T10:00:00Z',
      endsAt: '2026-12-01T10:00:00Z',
    }, cityAdmin)).rejects.toBeInstanceOf(BadRequestException);
    db.getAll.mockResolvedValue([{ exists: false }]);
    await expect(service.create('activities', {
      cityId: 'pune', title: 'x', description: 'y', startsAt: '2026-12-01T10:00:00Z',
      organisationIds: ['missing'],
    }, cityAdmin)).rejects.toBeInstanceOf(BadRequestException);
    expect(docs.size).toBe(0);
  });

  it('allows super admins to manage any city and rejects missing records', async () => {
    const { service } = makeHarness();
    const item = await service.create('accomplishments', {
      cityId: 'mumbai', title: 'Award', description: 'Won', achievedAt: '2026-11-01T00:00:00Z',
    }, superAdmin);
    expect((await service.get('accomplishments', item.id, superAdmin)).cityId).toBe('mumbai');
    await expect(service.get('accomplishments', 'missing', superAdmin)).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.remove('accomplishments', 'missing', superAdmin)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects duplicate affiliate IDs and preserves immutable city ownership on updates', async () => {
    const { service } = makeHarness();
    await expect(service.create('accomplishments', {
      cityId: 'pune', title: 'Award', description: 'Won', achievedAt: '2026-11-01T00:00:00Z',
      organisationIds: ['org-1', 'org-1'],
    }, cityAdmin)).rejects.toBeInstanceOf(BadRequestException);
    const item = await service.create('accomplishments', {
      cityId: 'pune', title: 'Award', description: 'Won', achievedAt: '2026-11-01T00:00:00Z',
    }, cityAdmin);
    const changed = await service.update('accomplishments', item.id, { title: 'New title' }, cityAdmin);
    expect(changed.cityId).toBe('pune');
    expect(changed.title).toBe('New title');
  });

  it('filters city admin lists to assigned cities even when requesting another city', async () => {
    const { service } = makeHarness({
      a: { id: 'a', cityId: 'pune', status: 'DRAFT', achievedAt: '2026-11-01' },
      b: { id: 'b', cityId: 'mumbai', status: 'DRAFT', achievedAt: '2026-11-02' },
    });
    expect((await service.list('accomplishments', cityAdmin, 'mumbai')).map((x) => x.id)).toEqual([]);
  });
});
