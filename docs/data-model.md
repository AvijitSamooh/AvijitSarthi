# Avijit Sahyog — Causes, Organisations & Media Data Model

## Scope

The content/discovery domain supports donation causes, affiliated organisations, beneficiaries, and managed image assets.

Financial models such as Donation, Payment, Allocation, Receipt and Mandate remain separate from the media domain.

## Donation allocation boundary

The donor allocates a donation across **Causes**, not individual Organisations:

```text
Donation
  └── DonationAllocation
        └── Cause
              └── affiliated Organisations (discovery/transparency)
```

## Entities

### Language

Stores supported backend content languages.

- `code` — stable language code
- `name` — English/display name
- `nativeName` — language's native name
- `isDefault` — fallback language
- `isActive` — availability

### Cause

Represents a donation bucket/cause.

- `slug` — stable API-friendly identifier
- `isActive` — public availability
- `displayOrder` — UI ordering

Names and descriptions are stored in the Firestore document's `translations` map, keyed by language code.

### Organisation

Represents an affiliated organisation associated with one or more causes.

Operational/contact fields include logo URL compatibility, website, phone, dedicated mobile number, email, address, location, active state and display order. Mobile numbers are normalized to Indian E.164 format and are exposed to the public cause response for contact actions. Names and descriptions are stored in the Firestore document's `translations` map, keyed by language code.

Managed images are represented by an embedded `media` association array on the Organisation document; each entry references a separate `media/{mediaId}` document.

### Beneficiary

Represents a person or initiative whose support can be transparently explored.

- `name`
- `photoUrl` — legacy/backward-compatible primary image URL
- `story`
- `supportedYear`
- `contributionAmount`
- `causeId`
- `organisationId`
- `isActive`
- `displayOrder`

Managed images are represented by an embedded `media` association array on the Beneficiary document; each entry references a separate `media/{mediaId}` document.

### Media

Represents a processed image stored in object storage.

- `storageKey` — unique Cloudflare R2 object key
- `mimeType` — persisted output MIME type
- `fileSize` — processed file size in bytes
- `width` / `height` — processed image dimensions
- timestamps

The application stores object metadata in `media/{mediaId}` Firestore documents rather than exposing storage implementation details to domain entities.

### OrganisationMedia

Explicit association between an Organisation and a Media record.

- `purpose` — `LOGO` or `GALLERY`
- `displayOrder` — gallery ordering
- `isPrimary` — identifies the preferred image

### BeneficiaryMedia

Explicit association between a Beneficiary and a Media record.

- `purpose` — `PROFILE` or `GALLERY`
- `displayOrder`
- `isPrimary`

## Media storage and processing

```text
Admin upload
    ↓
NestJS Media API
    ↓
Validate MIME type + size
    ↓
Sharp: auto-rotate + resize
    ↓
Convert to WebP
    ↓
Cloudflare R2
    ↓
Persist Media metadata in Firestore
    ↓
Attach Media to Organisation or Beneficiary
```

Current upload constraints:

- Accepted input: JPEG, PNG, WebP
- Maximum upload size: 10 MB
- Maximum processed dimension: 1920 px
- Output format: WebP (quality 82)

If Firestore metadata persistence fails after object upload, the backend attempts to remove the uploaded R2 object to avoid orphaned files.

The current `logoUrl` and `photoUrl` fields remain temporarily for backward compatibility. New gallery functionality should use the embedded media associations and referenced Media documents.

## Translation strategy

```text
Cause
  └── CauseTranslation ── Language

Organisation
  └── OrganisationTranslation ── Language
```

English remains the mandatory fallback language as defined by `docs/vision.md`.

## Important design decisions

1. Stable IDs are UUIDs.
2. Slugs are unique and intended for API/UI routing.
3. Content can be activated/deactivated without deleting historical references.
4. Translations are stored in language-keyed maps on Firestore documents.
5. Organisation documents store stable `causeIds` references; the backend resolves the referenced active Cause documents for public responses.
6. Organisation and Beneficiary documents embed explicit media association entries that reference shared Media documents. Services validate those references because Firestore does not enforce SQL foreign keys.
7. Object storage keys, rather than storage-provider URLs, are persisted as the canonical media identity.
8. Existing URL fields remain temporarily to avoid breaking existing clients.
9. Video is intentionally outside the current media foundation scope.

## Education domain split

Education is represented as two separate causes with distinct purposes:

- **Education** (`education`) — parent cause grouping education-related assistance and recognition.
- **Education Assistance** (`education-assistance`) — child cause for need-based support for students who need help continuing their education.
- **Pratibha Samman** (`pratibha-samman`) — recognition of exceptional achievements in education, profession, sports, arts, culture and community service.

The existing `education` cause is migrated to `education-assistance`. During production reconciliation, verify that historical donation allocations, Beneficiary `causeId` values and Organisation `causeIds` references point to the canonical Education Assistance ID. Firestore stores these as document-ID references rather than SQL foreign keys. Pratibha Samman is a separate category and does not reuse the assistance beneficiary workflow as an implicit award model.

## Current API additions

The impact domain exposes:

- `GET /beneficiaries`
- `GET /beneficiaries/:id`

The admin media foundation exposes:

- `GET /admin/media/verify`
- `POST /admin/media/upload`

Both media endpoints are protected by admin authorization.

## Flutter admin workflow

Administrators can manage images directly from the Organisation and Beneficiary editors. Images can be selected during initial creation or added later while editing.

Creation flow:

```text
Select primary/gallery images
        ↓
Create entity
        ↓
Upload selected images
        ↓
Attach Media records to the new entity
```

This sequencing avoids requiring a Flutter release when content images change and prevents entity identifiers from being required before the administrator starts filling out the form.


## Entity media management workflow

After an image is uploaded into the Media domain, an administrator explicitly attaches it to an Organisation or Beneficiary. Uploading does not automatically make an image public.

### Organisation media API

- `GET /admin/organisations/:id/media`
- `POST /admin/organisations/:id/media`
- `PATCH /admin/organisations/:id/media/:mediaId`
- `DELETE /admin/organisations/:id/media/:mediaId`

Supported purposes are `LOGO` and `GALLERY`.

### Admin beneficiary API

- `GET /admin/beneficiaries`
- `GET /admin/beneficiaries/:id`
- `POST /admin/beneficiaries`
- `PATCH /admin/beneficiaries/:id`
- `DELETE /admin/beneficiaries/:id`
- `PATCH /admin/beneficiaries/:id/activate`
- `PATCH /admin/beneficiaries/:id/deactivate`

### Beneficiary media API

- `GET /admin/beneficiaries/:id/media`
- `POST /admin/beneficiaries/:id/media`
- `PATCH /admin/beneficiaries/:id/media/:mediaId`
- `DELETE /admin/beneficiaries/:id/media/:mediaId`

Supported purposes are `PROFILE` and `GALLERY`.

### Association rules

1. The target entity and Media record must exist.
2. The same Media record cannot be attached to the same entity twice.
3. `displayOrder` controls gallery ordering.
4. Setting `isPrimary=true` clears any existing primary image for the same entity and purpose.
5. Removing an association does not delete the underlying Media Firestore document or Cloudflare R2 object. Orphan cleanup is intentionally a separate lifecycle concern.
6. A Media record may be reused by different entities, so attachment deletion is deliberately non-destructive.


## Public image delivery

Public Organisation and Beneficiary APIs now resolve attached Media records into client-ready image objects. Set `R2_PUBLIC_BASE_URL` to the Cloudflare R2 custom/public domain.

- Organisation responses expose `logoUrl` (preferring attached LOGO media) and `gallery`.
- Beneficiary responses expose `photoUrl` (preferring attached PROFILE media), `profileImage`, and `gallery`.
- Gallery items are ordered by `displayOrder`.
- Legacy `logoUrl` and `photoUrl` fields remain as fallbacks for backwards compatibility.
- Storage keys are not exposed as public API URLs when `R2_PUBLIC_BASE_URL` is configured.


## City content domain

Activities and Accomplishments are separate Firestore collections and do not reuse Cause, Beneficiary or HelpApplication records.

### Activity

- `id` — server-generated UUID
- `cityId` — immutable city ownership key
- `title`, `description`
- `startsAt`, optional `endsAt` — ISO-8601 instants; end cannot precede start
- `organisationIds` — unique references to existing `organisations/{id}` records; these are affiliate Organisations
- `status` — `DRAFT`, `PUBLISHED` or `ARCHIVED`
- `createdBy`, `updatedBy`, `createdAt`, `updatedAt`

### Accomplishment

- `id` — server-generated UUID
- `cityId` — immutable city ownership key
- `title`, `description`
- `achievedAt` — ISO-8601 instant
- `organisationIds` — unique references to existing `organisations/{id}` records
- `status` — `DRAFT`, `PUBLISHED` or `ARCHIVED`
- `createdBy`, `updatedBy`, `createdAt`, `updatedAt`

### City Admin assignment

The existing `users` collection gains `role: CITY_ADMIN` and `cityIds: string[]`. The city list is assigned by Super Admin only. Legacy user records without this field are treated as having no assigned cities. The backend resolves role and assignments from Firestore on every protected request; client-supplied city IDs are never authorization evidence. City ownership cannot be changed by an update request.

### Affiliate integrity and publication

1. Affiliates reference existing Organisation documents; no duplicate Affiliate entity is created.
2. Duplicate Organisation IDs and unknown references are rejected before writing content.
3. Public endpoints return PUBLISHED records only; drafts and archived content are not readable publicly.
4. City Admin list/detail/update/delete operations are restricted to assigned cities. ADMIN and SUPER_ADMIN retain platform-wide access.
5. Donor allocations continue to target Causes only.
