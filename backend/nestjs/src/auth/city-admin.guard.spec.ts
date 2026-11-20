import { ForbiddenException } from '@nestjs/common';
import { CityAdminGuard } from './city-admin.guard';

describe('CityAdminGuard', () => {
  const firebaseAuthGuard = { canActivate: jest.fn() };
  const users = { getByFirebaseUid: jest.fn() };
  const guard = new CityAdminGuard(firebaseAuthGuard as never, users as never);
  beforeEach(() => jest.clearAllMocks());
  const context = () => {
    const request: any = { user: { uid: 'uid-1' } };
    return { switchToHttp: () => ({ getRequest: () => request }), request } as any;
  };

  it.each(['CITY_ADMIN', 'ADMIN', 'SUPER_ADMIN'])('attaches the authenticated %s account to the request', async (role) => {
    firebaseAuthGuard.canActivate.mockResolvedValue(true);
    users.getByFirebaseUid.mockResolvedValue({ id: 'user-1', role, cityIds: ['pune'] });
    const ctx = context();
    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    expect(ctx.request.adminUser).toEqual(expect.objectContaining({ role, cityIds: ['pune'] }));
  });

  it('rejects regular users before controller execution', async () => {
    firebaseAuthGuard.canActivate.mockResolvedValue(true);
    users.getByFirebaseUid.mockResolvedValue({ id: 'user-1', role: 'USER' });
    await expect(guard.canActivate(context())).rejects.toBeInstanceOf(ForbiddenException);
  });
});
