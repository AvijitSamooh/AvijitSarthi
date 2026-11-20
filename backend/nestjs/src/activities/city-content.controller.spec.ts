import { AdminActivitiesController, ActivitiesController } from './activities.controller';
import { AdminAccomplishmentsController, AccomplishmentsController } from '../accomplishments/accomplishments.controller';

describe('city content controllers', () => {
  const service: any = {
    list: jest.fn(), get: jest.fn(), create: jest.fn(), update: jest.fn(), remove: jest.fn(),
  };
  beforeEach(() => jest.clearAllMocks());
  const actor: any = { adminUser: { id: 'u1', role: 'CITY_ADMIN', cityIds: ['pune'] } };

  it('passes authenticated actor to protected activity writes and reads', async () => {
    const controller = new AdminActivitiesController(service);
    const dto: any = { cityId: 'pune', title: 'Camp' };
    await controller.create(dto, actor);
    await controller.update('a1', { title: 'Updated' }, actor);
    await controller.remove('a1', actor);
    expect(service.create).toHaveBeenCalledWith('activities', dto, actor.adminUser);
    expect(service.update).toHaveBeenCalledWith('activities', 'a1', { title: 'Updated' }, actor.adminUser);
    expect(service.remove).toHaveBeenCalledWith('activities', 'a1', actor.adminUser);
  });

  it('keeps public endpoints read-only and filters through public service semantics', async () => {
    const controller = new ActivitiesController(service);
    await controller.list('pune');
    expect(service.list).toHaveBeenCalledWith('activities', undefined, 'pune');
    await controller.get('a1');
    expect(service.get).toHaveBeenCalledWith('activities', 'a1');
  });

  it('uses the same city-scoped contract for accomplishments', async () => {
    const admin = new AdminAccomplishmentsController(service);
    const dto: any = { cityId: 'pune', title: 'Award' };
    await admin.create(dto, actor);
    expect(service.create).toHaveBeenCalledWith('accomplishments', dto, actor.adminUser);
    const publicController = new AccomplishmentsController(service);
    await publicController.list();
    expect(service.list).toHaveBeenCalledWith('accomplishments', undefined, undefined);
  });
});
