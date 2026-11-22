import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from './../src/app.module';

describe('Application bootstrap dependency graph', () => {
  let app: INestApplication | undefined;

  beforeEach(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app?.close();
    app = undefined;
  });

  it('compiles the complete Nest application module graph', () => {
    expect(app).toBeDefined();
  });

  it('does not expose donation creation or record lookup before payment enablement', async () => {
    await request(app!.getHttpServer())
      .post('/donations')
      .send({
        amount: '100.00',
        currency: 'INR',
        allocations: [{ causeId: 'cause-1', amount: '100.00' }],
      })
      .expect(404);

    await request(app!.getHttpServer())
      .get('/donations/donation-1')
      .expect(404);
  });
});
