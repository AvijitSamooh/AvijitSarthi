# AvijitSahyog Firestore architecture

## Target architecture

Flutter -> Firebase Authentication -> NestJS API -> Cloud Firestore
                                      -> Cloudflare R2

Firebase Authentication already exists in the application. The **repository/runtime migration** is complete: NestJS uses Firestore as its application datastore and PostgreSQL/Prisma are no longer runtime dependencies. Production service deployment, historical-data reconciliation, backup/restore and retirement of any external database resources or secrets are separate operational checks; do not infer that they are complete from repository code alone. Track them in [the iteration plan](iteration-plan.md).

## Collection design

- users/{userId}
- causes/{causeId}
- organisations/{organisationId}
- beneficiaries/{beneficiaryId}
- helpApplications/{applicationId}
- helpApplicationVotes/{voteId}
- activities/{activityId}
- accomplishments/{accomplishmentId}
- platformSettings/downtime
- applicationRules/{ruleId}
- applicationWindows/{type}
- donations/{donationId}
- analyticsEvents/{eventId}
- auditLogs/{auditId}
- media/{mediaId}

Relational join tables are represented as embedded fields, references, or subcollections where that produces simpler Firestore reads. The design does not mechanically reproduce every former relational table.

## Runtime invariants

- Existing NestJS API routes and Flutter contracts remain stable unless a Firestore limitation requires an intentional API change.
- Firebase Admin credentials are server-only.
- Cloudflare R2 remains the image/object store.
- Application status transitions, admin authorization, vote uniqueness and donation validation remain server-enforced.
- Financial records are treated as append-only after payment confirmation.
- Firestore is the authoritative runtime persistence layer.

## Migration history

The historical PostgreSQL -> Firestore backfill was designed to be idempotent and reconciliation-gated. PostgreSQL data was retained during the transition for rollback/reconciliation. The current repository contains Firestore runtime services and no active Prisma/PostgreSQL packages, schema, migrations or CI database service.

Historical migration steps are retained in Git history for auditability; they are not active runtime commands. Production data reconciliation and retirement of any external database resource must be verified operationally before final infrastructure cleanup.
