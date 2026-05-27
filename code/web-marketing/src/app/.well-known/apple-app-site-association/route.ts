/**
 * Apple Universal Links manifest — served at
 *   https://tothanhthuy.cloud/.well-known/apple-app-site-association
 *
 * Apple FETCHES this file with `Content-Type: application/json` and the
 * filename MUST be exactly `apple-app-site-association` (no extension). We
 * use a route handler so Next.js controls the headers/content-type — a
 * static file would be served as text/plain by default on most hosts.
 *
 * Audit AndroidManifest.xml ↔ here: pathPrefix entries here must match
 * the intent-filter pathPrefix entries in
 * code/flutter/android/app/src/main/AndroidManifest.xml so the same
 * deep links open the app on both iOS + Android.
 *
 * Reference: https://developer.apple.com/documentation/xcode/supporting-associated-domains
 */
export const dynamic = 'force-static';

// REPLACE_WITH_APPLE_TEAM_ID — find at https://developer.apple.com/account →
// Membership → Team ID. Format: 10 chars alphanumeric. Memory note: this
// project's team id is FP8Z984262 (hnag-ios-signing-flow).
const APPLE_TEAM_ID = 'FP8Z984262';
const IOS_BUNDLE_ID = 'vn.hnag.hnag';

export function GET() {
  const body = {
    applinks: {
      apps: [],
      details: [
        {
          appIDs: [`${APPLE_TEAM_ID}.${IOS_BUNDLE_ID}`],
          paths: ['/r/*', '/f/*', '/c/*'],
          components: [
            { '/': '/r/*', comment: 'Restaurant detail deep link' },
            { '/': '/f/*', comment: 'Food detail deep link' },
            { '/': '/c/*', comment: 'Couple / community invite deep link' },
          ],
        },
      ],
    },
    // Web credentials (Sign in with Apple from web → opens app)
    webcredentials: {
      apps: [`${APPLE_TEAM_ID}.${IOS_BUNDLE_ID}`],
    },
  };
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      // Apple recommends short cache; updates need to propagate within a deploy.
      'Cache-Control': 'public, max-age=300',
    },
  });
}
