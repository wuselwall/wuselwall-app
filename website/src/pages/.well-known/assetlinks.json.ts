import type { APIRoute } from 'astro';
import { androidFingerprints, appLinks } from '../../config/site';

// Digital Asset Links: lets Android verify that the app may open wuselwall.app links
// (android:autoVerify). The fingerprints live in config/site.ts.
export const GET: APIRoute = () =>
  new Response(
    JSON.stringify(
      [
        {
          relation: ['delegate_permission/common.handle_all_urls'],
          target: {
            namespace: 'android_app',
            package_name: appLinks.androidPackage,
            sha256_cert_fingerprints: androidFingerprints,
          },
        },
      ],
      null,
      2,
    ),
    { headers: { 'Content-Type': 'application/json' } },
  );
