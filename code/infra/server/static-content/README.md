# Static Content (hnag-static container)

These files are deployed to `/opt/docker/hnag/static/` on ServerLinux and
served by the `hnag-static` nginx container at BOTH:
- `https://tothanhthuy.cloud/` (root domain — via Cloudflare Tunnel)
- `https://app.tothanhthuy.cloud/` (mobile downloads)

Source-of-truth lives here; sync to server with:

```bash
rsync -a code/infra/server/static-content/ ServerLinux:/opt/docker/hnag/static/
```

## Files

| File | Purpose |
| --- | --- |
| `.well-known/assetlinks.json` | Android App Links verification (needs real keystore SHA-256) |
| `.well-known/apple-app-site-association` | iOS Universal Links (team `FP8Z984262`, bundle `vn.hnag.hnag`) |
| `robots.txt` | Search engine policy |
| `sitemap.xml` | Sitemap pointer |

NOT versioned here (live only on server):

| File | Reason |
| --- | --- |
| `hnag.ipa` | 21 MB binary — produced by iOS build VM |
| `hnag-latest.apk` | 52 MB binary — produced by Android CI |
| `index.html` | Landing page — outside this directory's scope |
