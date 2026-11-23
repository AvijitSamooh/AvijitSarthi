import {
  ArgumentsHost,
  HttpException,
  UnauthorizedException,
} from '@nestjs/common';
import { PlatformHealthExceptionFilter } from './platform-health.exception-filter';

describe('PlatformHealthExceptionFilter', () => {
  const health = { recordEvent: jest.fn() };
  let filter: PlatformHealthExceptionFilter;

  const hostFor = (request: Record<string, unknown>) => {
    const response = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const host = {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => response,
      }),
    } as unknown as ArgumentsHost;
    return { host, response };
  };

  beforeEach(() => {
    jest.clearAllMocks();
    health.recordEvent.mockResolvedValue(undefined);
    filter = new PlatformHealthExceptionFilter(health as any);
  });

  it('records unauthorized requests as authentication failures', () => {
    const { host, response } = hostFor({
      originalUrl: '/admin/users?tab=all',
      url: '/admin/users?tab=all',
      method: 'GET',
    });
    const exception = new UnauthorizedException();

    filter.catch(exception, host);

    expect(health.recordEvent).toHaveBeenCalledWith({
      type: 'AUTH_FAILURE',
      statusCode: 401,
      route: '/admin/users?tab=all',
      method: 'GET',
      message: 'Unauthorized',
    });
    expect(response.status).toHaveBeenCalledWith(401);
    expect(response.json).toHaveBeenCalledWith(exception.getResponse());
  });

  it('classifies upload-route failures separately', () => {
    const { host, response } = hostFor({
      originalUrl: '/admin/media/upload?source=profile',
      url: '/admin/media/upload?source=profile',
      method: 'POST',
    });
    const exception = new HttpException('Upload rejected', 413);

    filter.catch(exception, host);

    expect(health.recordEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'UPLOAD_FAILURE',
        statusCode: 413,
        method: 'POST',
        message: 'Upload rejected',
      }),
    );
    expect(response.status).toHaveBeenCalledWith(413);
    expect(response.json).toHaveBeenCalledWith('Upload rejected');
  });

  it('returns a generic safe response for unexpected exceptions', () => {
    const { host, response } = hostFor({
      originalUrl: '/causes',
      url: '/causes',
      method: 'GET',
    });

    filter.catch(new Error('private backend detail'), host);

    expect(health.recordEvent).toHaveBeenCalledWith({
      type: 'HTTP_ERROR',
      statusCode: 500,
      route: '/causes',
      method: 'GET',
      message: 'private backend detail',
    });
    expect(response.status).toHaveBeenCalledWith(500);
    expect(response.json).toHaveBeenCalledWith({
      statusCode: 500,
      message: 'Internal server error',
    });
  });

  it('uses the request URL when originalUrl is unavailable', () => {
    const { host } = hostFor({
      url: '/organisations',
      method: 'GET',
    });

    filter.catch(new HttpException({ message: 'Bad request' }, 400), host);

    expect(health.recordEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'HTTP_ERROR',
        statusCode: 400,
        route: '/organisations',
      }),
    );
  });
});
