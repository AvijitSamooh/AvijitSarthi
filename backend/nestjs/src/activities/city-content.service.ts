import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { FirebaseService } from '../firebase/firebase.service';
import type { FirestoreUser } from '../users/firestore-users.service';

export type CityContentStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export interface CityContentInput {
  title?: string;
  description?: string;
  cityId?: string;
  startsAt?: string;
  endsAt?: string;
  achievedAt?: string;
  organisationIds?: string[];
  status?: CityContentStatus;
}
type ContentKind = 'activities' | 'accomplishments';

@Injectable()
export class CityContentService {
  constructor(private readonly firebase: FirebaseService) {}

  async list(kind: ContentKind, actor?: FirestoreUser, cityId?: string) {
    const snapshot = await this.firebase.db.collection(kind).get();
    return snapshot.docs.map((doc) => doc.data())
      .filter((item) => actor ? this.canAccessCity(actor, String(item.cityId)) : item.status === 'PUBLISHED')
      .filter((item) => !cityId || item.cityId === cityId)
      .sort((a, b) => this.dateValue(kind, b) - this.dateValue(kind, a));
  }

  async get(kind: ContentKind, id: string, actor?: FirestoreUser) {
    const snapshot = await this.firebase.db.collection(kind).doc(id).get();
    if (!snapshot.exists) throw new NotFoundException('Content was not found.');
    const item = snapshot.data()!;
    if (actor) this.assertCityAccess(actor, String(item.cityId));
    else if (item.status !== 'PUBLISHED') throw new NotFoundException('Content was not found.');
    return item;
  }

  async create(kind: ContentKind, input: CityContentInput, actor: FirestoreUser) {
    const cityId = input.cityId?.trim();
    if (!cityId) throw new BadRequestException('A city is required.');
    this.assertCityAccess(actor, cityId);
    await this.validateOrganisations(input.organisationIds ?? []);
    this.validateDates(kind, input);
    const id = randomUUID();
    const now = new Date();
    const item = {
      id, cityId, title: input.title!.trim(), description: input.description!.trim(),
      ...(kind === 'activities'
        ? { startsAt: new Date(input.startsAt!).toISOString(), endsAt: input.endsAt ? new Date(input.endsAt).toISOString() : null }
        : { achievedAt: new Date(input.achievedAt!).toISOString() }),
      organisationIds: [...new Set(input.organisationIds ?? [])],
      status: 'DRAFT' as const, createdBy: actor.id, updatedBy: actor.id, createdAt: now, updatedAt: now,
    };
    await this.firebase.db.collection(kind).doc(id).create(item);
    return item;
  }

  async update(kind: ContentKind, id: string, input: CityContentInput, actor: FirestoreUser) {
    const ref = this.firebase.db.collection(kind).doc(id);
    return this.firebase.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new NotFoundException('Content was not found.');
      const current = snapshot.data()!;
      this.assertCityAccess(actor, String(current.cityId));
      if (input.organisationIds) await this.validateOrganisations(input.organisationIds);
      this.validateDates(kind, { ...current, ...input });
      const patch: Record<string, unknown> = { updatedBy: actor.id, updatedAt: new Date() };
      if (input.title !== undefined) patch.title = input.title.trim();
      if (input.description !== undefined) patch.description = input.description.trim();
      if (input.organisationIds !== undefined) patch.organisationIds = [...new Set(input.organisationIds)];
      if (input.status !== undefined) patch.status = input.status;
      if (kind === 'activities') {
        if (input.startsAt !== undefined) patch.startsAt = new Date(input.startsAt).toISOString();
        if (input.endsAt !== undefined) patch.endsAt = input.endsAt ? new Date(input.endsAt).toISOString() : null;
      } else if (input.achievedAt !== undefined) patch.achievedAt = new Date(input.achievedAt).toISOString();
      transaction.update(ref, patch);
      return { ...current, ...patch };
    });
  }

  async remove(kind: ContentKind, id: string, actor: FirestoreUser) {
    const ref = this.firebase.db.collection(kind).doc(id);
    await this.firebase.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new NotFoundException('Content was not found.');
      this.assertCityAccess(actor, String(snapshot.data()!.cityId));
      transaction.delete(ref);
    });
    return { id, deleted: true };
  }

  private canAccessCity(actor: FirestoreUser, cityId: string) {
    return actor.role !== 'CITY_ADMIN' || (actor.cityIds ?? []).includes(cityId);
  }

  private assertCityAccess(actor: FirestoreUser, cityId: string) {
    if (!this.canAccessCity(actor, cityId)) throw new ForbiddenException('You are not assigned to this city.');
  }

  private async validateOrganisations(ids: string[]) {
    const unique = [...new Set(ids)];
    if (unique.length !== ids.length) throw new BadRequestException('Affiliated organisations must be unique.');
    if (!unique.length) return;
    const refs = unique.map((id) => this.firebase.db.collection('organisations').doc(id));
    const docs = await this.firebase.db.getAll(...refs);
    if (docs.some((doc) => !doc.exists)) throw new BadRequestException('Every affiliate must reference an existing organisation.');
  }

  private validateDates(kind: ContentKind, input: CityContentInput) {
    if (kind === 'activities' && input.startsAt && input.endsAt &&
      new Date(input.endsAt).getTime() < new Date(input.startsAt).getTime()) {
      throw new BadRequestException('Activity end time cannot be before its start time.');
    }
  }

  private dateValue(kind: ContentKind, item: Record<string, any>) {
    const value = kind === 'activities' ? item.startsAt : item.achievedAt;
    const parsed = new Date(value).getTime();
    return Number.isFinite(parsed) ? parsed : 0;
  }
}
