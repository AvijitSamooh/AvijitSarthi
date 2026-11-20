import { AdminUsersController } from './admin-users.controller';

describe('AdminUsersController city role assignment', () => {
  const service = { changeRole: jest.fn() };
  const controller = new AdminUsersController(service as never);

  beforeEach(() => jest.clearAllMocks());

  it('passes the city allow-list from the validated request body to the role service', async () => {
    const request: any = { user: { uid: 'firebase-root' } };
    const body: any = { role: 'CITY_ADMIN', cityIds: ['pune', 'mumbai'] };
    service.changeRole.mockResolvedValue({ id: 'user-1', role: 'CITY_ADMIN', cityIds: body.cityIds });
    await controller.changeRole('user-1', body, request);
    expect(service.changeRole).toHaveBeenCalledWith('user-1', 'firebase-root', 'CITY_ADMIN', ['pune', 'mumbai']);
  });
});
