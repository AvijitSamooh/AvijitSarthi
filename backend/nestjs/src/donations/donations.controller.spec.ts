import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { DonationsController } from './donations.controller';

describe('DonationsController', () => {
  const identity = { uid: 'firebase-user-1' };
  const service = {
    listMine: jest.fn(),
    findMine: jest.fn(),
    issueReceipt: jest.fn(),
    findReceipt: jest.fn(),
  };
  let controller: DonationsController;

  beforeEach(() => {
    jest.clearAllMocks();
    controller = new DonationsController(service as any);
  });

  it('requires Firebase authentication for every donor-history route', () => {
    expect(Reflect.getMetadata('__guards__', DonationsController)).toContain(FirebaseAuthGuard);
  });

  it('delegates history and detail using the verified Firebase identity', async () => {
    service.listMine.mockResolvedValue([]);
    service.findMine.mockResolvedValue({ id: 'donation-1' });
    const request = { user: identity } as any;

    await expect(controller.listMine(request)).resolves.toEqual([]);
    await expect(controller.findMine(request, 'donation-1')).resolves.toEqual({ id: 'donation-1' });
    expect(service.listMine).toHaveBeenCalledWith(identity);
    expect(service.findMine).toHaveBeenCalledWith(identity, 'donation-1');
  });

  it('delegates idempotent receipt issuance and lookup for the authenticated donor', async () => {
    service.issueReceipt.mockResolvedValue({ donationId: 'donation-1', language: 'hi' });
    service.findReceipt.mockResolvedValue({ donationId: 'donation-1' });
    const request = { user: identity } as any;

    await expect(controller.issueReceipt(request, 'donation-1', 'hi')).resolves.toEqual({
      donationId: 'donation-1', language: 'hi',
    });
    await expect(controller.findReceipt(request, 'donation-1')).resolves.toEqual({
      donationId: 'donation-1',
    });
    expect(service.issueReceipt).toHaveBeenCalledWith(identity, 'donation-1', 'hi');
    expect(service.findReceipt).toHaveBeenCalledWith(identity, 'donation-1');
  });
});
