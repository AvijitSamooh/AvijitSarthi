const { cert, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId !== 'avijitsahyog-firebase') {
    throw new Error('E2E seed is restricted to the Avijit Firebase emulator project.');
  }
  if (!['127.0.0.1:8080', 'localhost:8080'].includes(emulatorHost ?? '')) {
    throw new Error('Refusing to seed Firestore without the local Firestore emulator.');
  }
  if (!clientEmail || !privateKey) {
    throw new Error('Ephemeral Firebase Admin credentials are required for E2E seeding.');
  }

  const app = initializeApp({
    projectId,
    credential: cert({ projectId, clientEmail, privateKey }),
  }, 'avijit-android-e2e-seed');
  const db = getFirestore(app);
  const now = new Date();

  try {
    const activities = [
      {
        id: 'e2e-pune-published',
        cityId: 'pune',
        title: 'E2E Pune published activity',
        description: 'Published content loaded from the isolated Firestore emulator.',
        startsAt: '2026-12-02T10:00:00.000Z',
        endsAt: null,
        organisationIds: [],
        status: 'PUBLISHED',
      },
      {
        id: 'e2e-mumbai-published',
        cityId: 'mumbai',
        title: 'E2E Mumbai published activity',
        description: 'A second city fixture used to verify server-side filtering.',
        startsAt: '2026-12-03T10:00:00.000Z',
        endsAt: null,
        organisationIds: [],
        status: 'PUBLISHED',
      },
      {
        id: 'e2e-pune-draft',
        cityId: 'pune',
        title: 'E2E Pune draft activity',
        description: 'Draft content must never be visible through the public API.',
        startsAt: '2026-12-04T10:00:00.000Z',
        endsAt: null,
        organisationIds: [],
        status: 'DRAFT',
      },
    ];

    const accomplishments = [
      {
        id: 'e2e-pune-accomplishment',
        cityId: 'pune',
        title: 'E2E Pune published accomplishment',
        description: 'Published accomplishment loaded from the isolated Firestore emulator.',
        achievedAt: '2026-11-15T10:00:00.000Z',
        organisationIds: [],
        status: 'PUBLISHED',
      },
      {
        id: 'e2e-mumbai-accomplishment',
        cityId: 'mumbai',
        title: 'E2E Mumbai published accomplishment',
        description: 'A second city fixture used to verify accomplishment filtering.',
        achievedAt: '2026-11-16T10:00:00.000Z',
        organisationIds: [],
        status: 'PUBLISHED',
      },
    ];

    const causes = [
      {
        id: 'e2e-education',
        slug: 'education',
        parentId: null,
        isActive: true,
        displayOrder: 1,
        translations: { en: { name: 'E2E Education', description: 'Education support programmes.' } },
        childIds: ['e2e-education-assistance', 'e2e-pratibha-samman'],
        organisationIds: [],
      },
      {
        id: 'e2e-education-assistance',
        slug: 'education-assistance',
        parentId: 'e2e-education',
        isActive: true,
        displayOrder: 1,
        translations: { en: { name: 'E2E Education Assistance', description: 'Support for education needs.' } },
        childIds: [],
        organisationIds: [],
      },
      {
        id: 'e2e-pratibha-samman',
        slug: 'pratibha-samman',
        parentId: 'e2e-education',
        isActive: true,
        displayOrder: 2,
        translations: { en: { name: 'E2E Pratibha Samman', description: 'Recognising student achievement.' } },
        childIds: [],
        organisationIds: [],
      },
      {
        id: 'e2e-empty-parent',
        slug: 'empty-parent',
        parentId: null,
        isActive: true,
        displayOrder: 2,
        translations: { en: { name: 'E2E Empty Parent', description: 'No active child causes.' } },
        childIds: ['e2e-inactive-child'],
        organisationIds: [],
      },
      {
        id: 'e2e-inactive-child',
        slug: 'inactive-child',
        parentId: 'e2e-empty-parent',
        isActive: false,
        displayOrder: 1,
        translations: { en: { name: 'E2E Inactive Child', description: 'Must not be selectable.' } },
        childIds: [],
        organisationIds: [],
      },
    ];

    await Promise.all([
      ...activities.map((item) => db.collection('activities').doc(item.id).set({
        ...item,
        createdAt: now,
        updatedAt: now,
      })),
      ...accomplishments.map((item) => db.collection('accomplishments').doc(item.id).set({
        ...item,
        createdAt: now,
        updatedAt: now,
      })),
      ...causes.map((item) => db.collection('causes').doc(item.id).set({
        ...item,
        createdAt: now,
        updatedAt: now,
      })),
    ]);

    process.stdout.write(
      `Seeded ${activities.length} Activities, ${accomplishments.length} Accomplishments and ${causes.length} Causes into the local Firestore emulator.\n`,
    );
  } finally {
    await app.delete();
  }
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
  process.exitCode = 1;
});
