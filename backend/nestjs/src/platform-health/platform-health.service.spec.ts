import { PlatformHealthService } from './platform-health.service';

describe('PlatformHealthService', () => {
  const firestore = {
    recordEvent: jest.fn(),
    listRecent: jest.fn(),
    ping: jest.fn(),
  };
  let service: PlatformHealthService;

  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-11-23T00:00:00.000Z'));
    jest.clearAllMocks();
    service = new PlatformHealthService(firestore as any);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('persists operational events through Firestore', async () => {
    firestore.recordEvent.mockResolvedValue(undefined);
    const event = {
      type: 'HTTP_ERROR' as const,
      statusCode: 500,
      route: '/causes',
      method: 'GET',
      message: 'Upstream unavailable',
    };

    await service.recordEvent(event);

    expect(firestore.recordEvent).toHaveBeenCalledWith(event);
  });

  it('does not break application requests when event persistence fails', async () => {
    firestore.recordEvent.mockRejectedValue(new Error('Firestore unavailable'));

    await expect(
      service.recordEvent({ type: 'APP_ERROR', message: 'client failure' }),
    ).resolves.toBeUndefined();
  });

  it('aggregates recent error counts, deployment metadata and recent events', async () => {
    const events = [
      {
        id: 'event-1',
        type: 'HTTP_ERROR',
        statusCode: 500,
        route: '/causes',
        method: 'GET',
        message: 'server error',
        createdAt: new Date('2026-11-22T12:00:00.000Z'),
      },
      {
        id: 'event-2',
        type: 'AUTH_FAILURE',
        statusCode: 401,
        route: '/auth/me',
        method: 'GET',
        message: 'unauthorized',
        createdAt: new Date('2026-11-20T12:00:00.000Z'),
      },
      {
        id: 'event-3',
        type: 'APP_ERROR',
        statusCode: null,
        route: null,
        method: null,
        message: 'client error',
        createdAt: new Date('2026-11-22T23:00:00.000Z'),
      },
    ];
    firestore.listRecent.mockResolvedValue(events);
    firestore.ping.mockResolvedValue(undefined);

    const summary = await service.getSummary();

    expect(firestore.listRecent).toHaveBeenCalledWith(7);
    expect(summary).toMatchObject({
      status: 'healthy',
      database: 'ok',
      errors24h: 1,
      authFailures24h: 0,
      uploadFailures24h: 0,
      appErrors24h: 1,
      crashes24h: 0,
      last7Days: {
        HTTP_ERROR: 1,
        AUTH_FAILURE: 1,
        APP_ERROR: 1,
      },
    });
    expect(summary.api.uptimeSeconds).toBeGreaterThanOrEqual(0);
    expect(summary.recentEvents).toHaveLength(3);
    expect(summary.recentEvents[0].createdAt).toBe(
      '2026-11-22T12:00:00.000Z',
    );
    expect(summary.deployment).toEqual(
      expect.objectContaining({ environment: 'test' }),
    );
  });

  it('reports database errors without throwing from the health summary helper', async () => {
    firestore.ping.mockRejectedValue(new Error('Firestore unavailable'));

    await expect(service.checkDatabase()).resolves.toBe('error');
  });

  it('reports database readiness when the Firestore ping succeeds', async () => {
    firestore.ping.mockResolvedValue(undefined);

    await expect(service.checkDatabase()).resolves.toBe('ok');
  });
});
