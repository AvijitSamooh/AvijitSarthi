import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import type { Request } from 'express';
import { FirestoreUsersService, type FirestoreUser } from '../users/firestore-users.service';
import type { AuthenticatedRequest } from './auth.types';
import { FirebaseAuthGuard } from './firebase-auth.guard';

export type CityAdminRequest = Request & AuthenticatedRequest & { adminUser: FirestoreUser };

@Injectable()
export class CityAdminGuard implements CanActivate {
  constructor(
    private readonly firebaseAuthGuard: FirebaseAuthGuard,
    private readonly users: FirestoreUsersService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    await this.firebaseAuthGuard.canActivate(context);
    const request = context.switchToHttp().getRequest<CityAdminRequest>();
    if (!request.user?.uid) throw new UnauthorizedException();
    const user = await this.users.getByFirebaseUid(request.user.uid);
    if (!user || !['ADMIN', 'SUPER_ADMIN', 'CITY_ADMIN'].includes(user.role)) {
      throw new ForbiddenException('City administrator access is required.');
    }
    request.adminUser = user;
    return true;
  }
}
