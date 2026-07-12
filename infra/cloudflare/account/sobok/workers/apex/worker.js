// Minimal apex Worker for sobok.cc.
//
// AdSense registers sites at the registrable domain, so the (top-level) sobok.cc
// site — which already covers stella.sobok.cc as a subdomain — must serve the
// ownership-verification signals itself; the subdomain cannot be verified alone.
// Until apps/web ships to the apex, this stub answers:
//   - GET /ads.txt     Authorized Digital Sellers for pub-5167766222238626
//   - anything else     a tiny landing page carrying the google-adsense-account meta tag
//
// Uploaded inline by Terraform (see workers.tf) — no build step, no CI.

const ADS_TXT = `google.com, pub-5167766222238626, DIRECT, f08c47fec0942fa0
subdomain=stella.sobok.cc
`

const LANDING = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="google-adsense-account" content="ca-pub-5167766222238626">
<title>소복</title>
</head>
<body style="margin:0;min-height:100dvh;display:grid;place-items:center;background:#0a0618;color:#fff;font-family:system-ui,-apple-system,sans-serif">
<main style="text-align:center;padding:2rem">
<h1 style="margin:0 0 .5rem;font-size:1.5rem;font-weight:600">소복</h1>
<p style="margin:0;opacity:.7">곧 찾아올게요.</p>
</main>
</body>
</html>
`

export default {
  fetch(request) {
    const { pathname } = new URL(request.url)

    if (pathname === '/ads.txt') {
      return new Response(ADS_TXT, {
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      })
    }

    return new Response(LANDING, {
      headers: { 'content-type': 'text/html; charset=utf-8' },
    })
  },
}
