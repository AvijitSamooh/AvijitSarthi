import { ExecutionContext, ServiceUnavailableException } from '@nestjs/common';
import { PlatformDowntimeGuard } from './platform-downtime.guard';

describe('PlatformDowntimeGuard', () => {
  const downtime = { get: jest.fn() };
  const tokenVerifier = { verify: jest.fn() };
  const users = { getByFirebaseUid: jest.fn() };
  let guard: PlatformDowntimeGuard;

  const enabledSettings = {
    enabled: true,
    startTime: '00:00',
    endTime: '00:00',
    message: 'Planned maintenance',
    updatedAt: null,
  };

  const contextFor = (path: string, authorization?: string) => {
    const request = {
      path,
      header: jest.fn((name: string) =>
        name.toLowerCase() === 'authorization' ? authorization : undefined,
      ),
    };
    return {
      context: {
        switchToHttp: () => ({ getRequest: () => request }),
      } as unknown as ExecutionContext,
      request,
    };
  };

  beforeEach(() => {
    jest.resetAllMocks();
    downtime.get.mockResolvedValue(enabledSettings);
    guard = new PlatformDowntimeGuard(
      downtime as any,
      tokenVerifier as any,
      users as any,
    );
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it.each([
    '/health',
    '/health/ready',
    '/platform-health',
    '/platform-health/summary',
    '/auth/me',
    '/platform-downtime',
  ])('keeps recovery endpoint %s available during downtime', async (path) => {
    const { context } = contextFor(path);

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(downtime.get).not.toHaveBeenCalled();
  });

  it('fails open when the downtime control-plane read fails', async () => {
    downtime.get.mockRejectedValue(new Error('Firestore unavailable'));
    const { context } = contextFor('/causes');

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it('allows requests when downtime is disabled', async () => {
    downtime.get.mockResolvedValue({ ...enabledSettings, enabled: false });
    const { context } = contextFor('/causes');

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });

  it('blocks an unauthenticated request during an active maintenance window', async () => {
    const { context } = contextFor('/causes');

    let thrown: unknown;
    try {
      await guard.canActivate(context);
    } catch (error) {
      thrown = error;
    }

    expect(thrown).toBeInstanceOf(ServiceUnavailableException);
    expect((thrown as ServiceUnavailableException).getResponse()).toMatchObject({
      statusCode: 503,
      code: 'PLATFORM_DOWNTIME',
      message: 'Planned maintenance',
    });
  });

  it('allows a verified Super Admin during an active maintenance window', async () => {
    tokenVerifier.verify.mockResolvedValue({ uid: 'super-admin-uid' });
    users.getByFirebaseUid.mockResolvedValue({ role: 'SUPER_ADMIN' });
    const { context } = contextFor('/admin/users', 'Bearer valid-token');

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(tokenVerifier.verify).toHaveBeenCalledWith('valid-token');
    expect(users.getByFirebaseUid).toHaveBeenCalledWith('super-admin-uid');
  });

  it('does not allow a normal user through an active maintenance window', async () => {
    tokenVerifier.verify.mockResolvedValue({ uid: 'user-uid' });
    users.getByFirebaseUid.mockResolvedValue({ role: 'USER' });
    const { context } = contextFor('/causes', 'Bearer user-token');

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('treats invalid tokens as non-admin requests during downtime', async () => {
    tokenVerifier.verify.mockRejectedValue(new Error('invalid token'));
    const { context } = contextFor('/causes', 'Bearer expired-token');

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(users.getByFirebaseUid).not.toHaveBeenCalled();
  });

  it('handles an overnight maintenance window using India local time', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-11-23T00:00:00.000Z')); // 05:30 in Asia/Kolkata
    downtime.get.mockResolvedValue({
      ...enabledSettings,
      startTime: '21:00',
      endTime: '08:00',
    });
    const { context } = contextFor('/causes');

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('allows requests outside the configured overnight window', async () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-11-23T05:00:00.000Z')); // 10:30 in Asia/Kolkata
    downtime.get.mockResolvedValue({
      ...enabledSettings,
      startTime: '21:00',
      endTime: '08:00',
    });
    const { context } = contextFor('/causes');

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });
});
