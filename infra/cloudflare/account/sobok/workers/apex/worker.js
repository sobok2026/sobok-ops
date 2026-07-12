// Apex Worker for sobok.cc.
//
// AdSense registers sites at the registrable domain, so the sobok.cc site (which
// covers stella.sobok.cc as a subdomain) has to answer both the ownership checks
// AND the approval review on the apex itself. Until apps/web ships to sobok.cc,
// this Worker serves:
//   - GET /ads.txt     Authorized Digital Sellers for pub-5167766222238626
//   - anything else     a real landing page: google-adsense-account meta tag, the
//                       AdSense loader, substantive copy, and a prominent link to
//                       the live tool at stella.sobok.cc so the reviewer can reach
//                       the content-rich pages.
//
// Uploaded inline by Terraform (see workers.tf) — no build step, no CI. When
// apps/web ships to the apex, delete this module and rebind to the real Worker.

const ADS_TXT = `google.com, pub-5167766222238626, DIRECT, f08c47fec0942fa0
subdomain=stella.sobok.cc
`

const LANDING = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="google-adsense-account" content="ca-pub-5167766222238626">
<title>소복 — 별과 운세로 여는 하루</title>
<meta name="description" content="소복은 별자리와 운세로 하루를 여는 서비스예요. 별자리 도구 별무리에서 내 태양·달·상승 별자리와 오늘의 운세를 확인해 보세요.">
<link rel="canonical" href="https://sobok.cc/">
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-5167766222238626" crossorigin="anonymous"></script>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100dvh;
    background: radial-gradient(120% 80% at 50% -10%, #1a1140 0%, #0a0618 60%);
    color: #f4f1ff;
    font-family: system-ui, -apple-system, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
    line-height: 1.7;
  }
  a { color: inherit; }
  .wrap { max-width: 720px; margin: 0 auto; padding: 4rem 1.5rem 5rem; }
  header .brand { font-size: 1.1rem; font-weight: 700; letter-spacing: .02em; }
  h1 { font-size: clamp(2rem, 6vw, 2.75rem); line-height: 1.25; margin: 2.5rem 0 1rem; }
  .lead { font-size: 1.15rem; opacity: .85; margin: 0 0 2rem; }
  .cta {
    display: inline-block; margin: .5rem 0 3.5rem; padding: .9rem 1.6rem;
    background: #7c6cff; color: #fff; font-weight: 700; text-decoration: none;
    border-radius: 999px;
  }
  .cta:hover { background: #9184ff; }
  h2 { font-size: 1.35rem; margin: 3rem 0 1rem; }
  .feature { margin: 0 0 1.5rem; }
  .feature h3 { font-size: 1.05rem; margin: 0 0 .35rem; }
  .feature p { margin: 0; opacity: .82; }
  footer { margin-top: 4rem; padding-top: 1.5rem; border-top: 1px solid rgba(255,255,255,.1); font-size: .9rem; opacity: .6; }
  footer a { text-decoration: none; }
</style>
</head>
<body>
<div class="wrap">
  <header><span class="brand">소복 · 별무리</span></header>

  <h1>별과 운세로<br>여는 하루</h1>
  <p class="lead">
    소복은 별자리와 운세로 하루를 여는 서비스예요. 첫 도구인 <strong>별무리</strong>는
    태어난 순간의 하늘을 계산해 나의 별자리와 성격, 그리고 오늘의 흐름을 읽어 드려요.
    설치도 회원가입도 없이, 브라우저에서 바로 확인할 수 있어요.
  </p>
  <a class="cta" href="https://stella.sobok.cc/">별무리에서 내 별자리 보기 →</a>

  <h2>별무리로 할 수 있는 것</h2>

  <div class="feature">
    <h3>나의 별자리와 성격</h3>
    <p>생년월일과 태어난 시각, 출생지를 넣으면 태양·달·상승 별자리를 계산하고
       그 조합이 말해 주는 성격과 기질을 풀어 드려요.</p>
  </div>

  <div class="feature">
    <h3>오늘의 운세</h3>
    <p>매일 달라지는 별의 흐름을 바탕으로 오늘 하루의 기운과 마음가짐을 짚어 드려요.</p>
  </div>

  <div class="feature">
    <h3>깊이 있는 장문 리딩</h3>
    <p>아홉 개의 장으로 이어지는 긴 호흡의 해석으로, 나를 더 천천히 들여다볼 수 있어요.</p>
  </div>

  <p>
    별무리는 계산부터 해석까지 모두 브라우저 안에서 이루어져요. 입력한 정보는 별자리를
    계산하는 데에만 쓰이고, 결과는 언제든 다시 열어볼 수 있어요.
    <a href="https://stella.sobok.cc/">stella.sobok.cc</a> 에서 지금 만나 보세요.
  </p>

  <footer>
    <nav style="margin-bottom:.6rem">
      <a href="https://stella.sobok.cc/ko/privacy/">개인정보처리방침</a>
      ·
      <a href="https://stella.sobok.cc/ko/terms/">이용약관</a>
    </nav>
    © 2026 소복 · <a href="https://stella.sobok.cc/">stella.sobok.cc</a>
  </footer>
</div>
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
