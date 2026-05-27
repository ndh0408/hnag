/**
 * Android App Links verification file.
 *
 * Reachable at: https://tothanhthuy.cloud/.well-known/assetlinks.json
 *
 * The Android system fetches this on app install (because
 * `android:autoVerify="true"` is set on the deep-link intent-filter in
 * AndroidManifest.xml). If the package name + SHA-256 fingerprint of the
 * APK signing key matches, Android opens https://tothanhthuy.cloud/r/...
 * etc. directly in the app without the "Open with" chooser.
 *
 * To rotate the signing fingerprint without breaking deep links, you can
 * list multiple `sha256_cert_fingerprints` entries — keep the old one in
 * the array for ~30 days after switching keys, so users who haven't
 * updated still resolve to the verified app.
 *
 * Real bundle id is `vn.hnag.hnag` (memory hnag-static-file-hosting).
 */

import { NextResponse } from 'next/server';

// Comma-separated colon-delimited SHA-256 fingerprints of the Android
// signing certificate(s). Configure via env so a key rotation needs no
// code change. Pull from `keytool -list -v -keystore <release.keystore>`
// (`SHA256: AA:BB:...`), strip the `SHA256:` prefix.
const FINGERPRINTS = (process.env.ANDROID_SHA256_FINGERPRINTS ?? '')
  .split(',')
  .map((s) => s.trim().toUpperCase())
  .filter(Boolean);

const PACKAGE = process.env.ANDROID_PACKAGE_NAME ?? 'vn.hnag.hnag';

export function GET() {
  if (!FINGERPRINTS.length) {
    // Empty (but well-formed) file — Android will reject autoVerify, falling
    // back to the chooser dialog rather than silently failing.
    return NextResponse.json([], { status: 200 });
  }
  return NextResponse.json(
    [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: PACKAGE,
          sha256_cert_fingerprints: FINGERPRINTS,
        },
      },
    ],
    {
      // Android caches this for 24h by default; small max-age keeps key
      // rotations from being too slow to propagate.
      headers: { 'Cache-Control': 'public, max-age=3600' },
    },
  );
}
