import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(path, 'utf8');

function workflowEvents(path) {
  const lines = read(path).split(/\r?\n/);
  const onIndex = lines.findIndex((line) => /^on:\s*(?:#.*)?$/.test(line));
  assert.notEqual(onIndex, -1, `${path} must declare top-level workflow triggers`);

  const events = [];
  for (let index = onIndex + 1; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.trim() || line.trim().startsWith('#')) continue;

    const indentation = line.match(/^ */)?.[0].length ?? 0;
    if (indentation === 0) break;
    if (indentation !== 2) continue;

    const match = line.match(/^ {2}([A-Za-z0-9_-]+):/);
    if (match) events.push(match[1]);
  }
  return events;
}

function expectEvents(path, expected) {
  assert.deepEqual(
    workflowEvents(path).sort(),
    [...expected].sort(),
    `${path} trigger policy changed; release workflows must remain manually controlled`,
  );
}

function expectContains(content, pattern, message) {
  assert.match(content, pattern, message);
}

function expectIncludes(content, value, message) {
  assert.ok(content.includes(value), message);
}

const release = read('.github/workflows/android-release.yml');
const publish = read('.github/workflows/android-publish.yml');
const control = read('.github/workflows/release-control.yml');

expectEvents('.github/workflows/android-release.yml', ['workflow_dispatch', 'workflow_call']);
expectEvents('.github/workflows/android-publish.yml', ['workflow_dispatch']);
expectEvents('.github/workflows/release-control.yml', ['workflow_dispatch']);

expectIncludes(release, 'com.avijitsamooh.avijitsahyog', 'Android release package identity must remain unchanged');
expectIncludes(release, 'avijitsahyog-firebase', 'Android release must validate the production Firebase project');
for (const secret of [
  'ANDROID_KEYSTORE_BASE64',
  'ANDROID_STORE_PASSWORD',
  'ANDROID_KEY_PASSWORD',
  'ANDROID_KEY_ALIAS',
]) {
  expectIncludes(release, secret, `Android signing secret reference missing: ${secret}`);
}
expectIncludes(release, 'API_BASE_URL', 'Android release must receive the production backend URL');
expectIncludes(release, 'https://*', 'Android release must reject non-HTTPS backend URLs');
assert.doesNotMatch(release, /upload-google-play/i, 'Android Release Bundle must build artifacts only');

expectIncludes(publish, 'com.avijitsamooh.avijitsahyog', 'Google Play package identity must remain unchanged');
expectIncludes(publish, 'tracks: qa,alpha', 'Google Play internal and closed tracks must remain qa,alpha');
expectIncludes(publish, 'PLAY_STORE_SERVICE_ACCOUNT_JSON', 'Google Play credential reference is missing');
expectIncludes(publish, 'build_run_id', 'Manual publishing must require an explicit build run ID');
expectIncludes(publish, '.github/workflows/android-release.yml', 'Publishing must accept only Android Release Bundle runs');
expectIncludes(publish, 'HEAD_BRANCH" != "master"', 'Publishing must reject artifacts from non-master branches');
expectIncludes(publish, 'HEAD_SHA" != "$MASTER_SHA"', 'Publishing must reject artifacts not built from current master');
expectIncludes(publish, 'STATUS" != "completed"', 'Publishing must reject incomplete build runs');
expectIncludes(publish, 'CONCLUSION" != "success"', 'Publishing must reject unsuccessful build runs');
expectIncludes(publish, 'AAB_COUNT', 'Publishing must validate the selected AAB artifact count');

expectContains(
  control,
  /release_android:[\s\S]*?default:\s*true/,
  'Release Control must keep Android selected by default',
);
expectContains(
  control,
  /release_backend:[\s\S]*?default:\s*true/,
  'Release Control must keep Backend selected by default',
);
expectIncludes(control, 'tracks: qa,alpha', 'Release Control must preserve the internal and closed Play tracks');
expectIncludes(control, 'com.avijitsamooh.avijitsahyog', 'Release Control must preserve the Android package identity');
expectIncludes(control, 'PLAY_STORE_SERVICE_ACCOUNT_JSON', 'Release Control Play credential reference is missing');
expectIncludes(control, 'inputs.release_android', 'Android release must remain independently selectable');
expectIncludes(control, 'inputs.release_backend', 'Backend release must remain independently selectable');

console.log('Android release workflow contract passed: manual triggers, package, Firebase, signing, backend, preflight and Play tracks are intact.');
