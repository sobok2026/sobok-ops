# Cloudflare 인프라

Cloudflare 프로덕션 상태는 HCP Terraform `sobok2026` 조직의 `cloudflare` 프로젝트에서 관리한다. 이 레포가 source of truth이며 Dashboard 변경은 break-glass 용도로만 사용하고 즉시 Terraform에 반영한다.

## 워크스페이스

| 경로                          | HCP Terraform 워크스페이스 | 소유 범위                                                                                                                                      |
| ----------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `account/sobok/workers`       | `account-workers`          | stella, horn, zwds Worker와 custom domain                                                                                                      |
| `account/sobok/vibe`          | `account-vibe`             | vibe Worker custom domain, Hyperdrive, 딥타입 runtime secret                                                                                   |
| `account/sobok/stella`        | `account-stella`           | stella Worker Hyperdrive, stella 댓글 runtime secret                                                                                           |
| `account/sobok/secrets-store` | `account-secrets-store`    | 계정 Secrets Store 스토어 리소스. `store_id`를 output으로 노출                                                                                 |
| `account/sobok/tunnel`        | `account-tunnel`           | production cloudflared tunnel과 ingress                                                                                                        |
| `account/sobok/turnstile`     | `account-turnstile`        | 공유 Turnstile widget과 그 위젯 secret의 스토어 기록                                                                                           |
| `zone/sobok.cc/settings`      | `zone-settings`            | 저변동 Zone baseline, Universal SSL, Managed Transforms                                                                                        |
| `zone/sobok.cc/security`      | `zone-security`            | Bot Management(Bot Fight Mode·AI Labyrinth·managed robots.txt), Leaked Credential Detection, URL Normalization, PortOne webhook 선행 허용 규칙 |
| `zone/sobok.cc/dns`           | `zone-dns`                 | DNSSEC와 향후 명시적으로 관리할 DNS 레코드                                                                                                     |

워크스페이스는 값의 자료형이나 Dashboard 메뉴가 아니라 상태 소유권과 변경 위험으로 나눈다.

- 각 Secrets Store secret은 자신의 **값 출처**를 소유한 워크스페이스가 쓴다. 딥타입 secret은 `account-vibe`,
  stella 댓글 secret은 `account-stella`, 공유 Turnstile secret은 위젯을 만드는 `account-turnstile`이 소유한다.
  제품 워크스페이스가 공유 secret을 소유하지 않는다(그러면 소유자가 자의적이 되고 blast radius가 뒤섞인다).
  스토어 리소스 자체는 중립 `account-secrets-store`가 소유하고 `store_id`를 output으로 노출하며, 세 소비
  워크스페이스는 그것을 `terraform_remote_state`로 읽어 store id를 손으로 주입하지 않는다.
- 모든 `cloudflare_zone_setting`은 값이 on/off, enum, 숫자, 객체 중 무엇이든 `settings` 한 곳에서
  소유한다. SSL/TLS 설정을 별도 state에서도 소유하게 만들지 않는다.
- Universal SSL과 Managed Transforms는 같은 저변동 baseline이므로 `settings`의 별도 `.tf` 파일로
  둔다. 리소스 종류마다 워크스페이스를 만들지 않는다.
- Bot Fight Mode와 PortOne IP 허용 규칙은 함께 적용·롤백되어야 하므로 `security`가 같이 소유한다.
- Leaked Credential Detection도 `security`가 소유한다. Free 플랜에서는 detection 토글만 두고 mitigation
  규칙은 두지 않는다(뒤의 "의도적으로 baseline에서 제외한 기능" 참고). 유료 플랜에서 엣지 mitigation을
  추가하면 detection과 함께 적용·롤백되도록 같은 `security`에 둔다.
- URL Normalization은 인코딩된 경로로 WAF·rate-limit 평가를 우회하는 것을 막는 보안 컨트롤이라 `security`가
  소유한다(대시보드 메뉴는 Rules→Settings지만 상태 소유권 기준으로 배치한다). 현재 `scope = "incoming"`은
  origin 경로를 바꾸지 않고 CF 측 평가만 정규화한다. `scope = "both"`는 WAF-vs-origin 경로 desync까지 닫지만
  터널→Envoy가 받는 경로를 정규화하므로 Envoy·PortOne·better-auth 경로 검증 뒤에 올린다.
- DNSSEC은 registrar 위임 상태와 롤백 순서가 있어 `dns`로 격리한다. Worker custom domain이 자동으로
  만든 DNS 레코드는 해당 account 워크스페이스가 계속 소유하며 `dns`에 중복 선언하지 않는다.
- Ruleset이 필요해지면 `rulesets/waf-custom`, `rulesets/rate-limit`, `rulesets/cache`,
  `rulesets/redirects`처럼 **Cloudflare phase별** root를 그때 추가한다. 한 phase의 entry-point
  ruleset을 여러 state가 나누어 소유하지 않는다.

## HCP Terraform 설정

세 Zone 워크스페이스를 VCS-driven, manual apply로 만들고 위 표의 경로를 working directory로
지정한다. pull request는 speculative plan을 실행하고 main 반영 후 apply는 명시적으로 승인한다.

프로젝트 변수 세트에 다음 환경 변수를 둔다.

| 키                     | 종류        | Sensitive |
| ---------------------- | ----------- | --------- |
| `CLOUDFLARE_API_TOKEN` | Environment | Yes       |

토큰은 `sobok.cc` Zone으로 resource scope를 제한하고 워크스페이스가 사용하는 최소 권한만 부여한다.

| 워크스페이스             | 필요한 권한                                                                                      |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| `zone-sobok-cc-settings` | Zone Read, Zone Settings Read/Write, SSL and Certificates Read/Write, Managed Headers Read/Write |
| `zone-sobok-cc-security` | Zone Read, Bot Management Read/Write, Zone WAF Read/Write, Firewall Services Read/Write          |
| `zone-sobok-cc-dns`      | Zone Read, DNS Read/Write                                                                        |

## Provider lifecycle 경고

Cloudflare provider v5의 `cloudflare_universal_ssl_setting`, `cloudflare_zone_setting`,
`cloudflare_bot_management`는 Zone에 항상 존재하는 singleton 설정을 나타낸다. 최초 plan에서
`Resource Destruction Considerations` 경고가 출력되는 것은 정상이며 apply 실패를 의미하지 않는다.
이 리소스의 Delete는 Cloudflare 설정을 비활성화하지 않고 Terraform state에서만 제거한다.

잘못된 일괄 destroy를 막기 위해 Universal SSL, scalar Zone settings, HSTS, Bot Management, Leaked
Credential Detection, URL Normalization에 `prevent_destroy`를 둔다. 설정을 해제할 때는 먼저 원하는 비활성화 값으로 변경해 apply하고 실제
응답을 확인한다. 실제 설정은 유지한 채 Terraform 관리만 넘길 때는 resource를 `destroy = false`인
Terraform `removed` block으로 교체해 state에서만 제거한다. 일반 `terraform destroy`나 resource
block의 단순 삭제를 해제 절차로 사용하지 않는다.

## 최초 적용 순서

1. `zone-sobok-cc-settings`를 apply하고 HTTP가 HTTPS로 redirect되는지, 모든 운영 hostname이 정상
   TLS 응답을 반환하는지 확인한다.
2. `zone-sobok-cc-dns`를 apply한다. registrar도 Cloudflare이므로 CDS/CDNSKEY를 통해 DS가 자동
   반영되며 보통 1~2일이 걸린다. `dig +short DS sobok.cc`와 Cloudflare의 DNSSEC 상태로 확인한다.
3. `zone-sobok-cc-security`를 apply한다. Terraform 의존성 때문에 PortOne V2 webhook IP 허용 규칙이
   Bot Fight Mode보다 먼저 생성된다.

HSTS의 `preload` 지시어를 켜는 것만으로 브라우저 preload 목록에 등록되지는 않는다. 모든
서브도메인의 HTTPS를 검증한 뒤 별도 등록을 진행한다. 등록 후에는 되돌리는 데 오래 걸리므로 HSTS와
DNSSEC을 일반적인 일괄 destroy 대상으로 취급하지 않는다.

Bot Management API는 Terraform 리소스를 destroy해도 Bot Fight Mode를 끄지 않는다. 이 상태에서 IP
허용 규칙만 삭제되는 사고를 막기 위해 리소스에 `prevent_destroy`를 둔다. 해제할 때는 먼저
`fight_mode = false`로 변경해 apply하고 실제 비활성화를 확인한 다음 리소스와 허용 규칙을 제거한다.

Bot Fight Mode는 WAF custom rule의 Skip으로 우회할 수 없다. PortOne이 공식 안내하는 V2 webhook
IP `52.78.5.241`에 Zone IP Access Rule의 Allow를 적용하며, 이 IP는 Zone의 다른 보안 검사도
우회한다. PortOne의 변경 사전 안내를 받으면 기존 IP를 유지한 채 새 IP를 추가해 먼저 apply하고,
새 IP 수신을 확인한 다음 기존 IP를 제거한다.

## Terraform으로 관리하지 않는 설정

이 레포가 source of truth이지만, provider가 리소스를 제공하지 않아 Terraform으로 담을 수 없는 설정은
예외적으로 대시보드/API로 관리하고 여기에 현재 상태(활성/비활성)와 함께 명시한다. Terraform이 드리프트를
감지하지 못하므로 주기적으로 대시보드 상태를 확인한다.

- Page Shield(대시보드의 Client-side security) script 모니터링 — **활성화됨(2026-07 수동)**: 실행되는
  3rd-party JavaScript 인벤토리를 report-only로 수집해 공급망·스키밍(Magecart) 가시성을 준다. 아무것도
  차단하지 않아 결제·인증 트래픽에 안전하다.
  - Cloudflare provider v5에는 Page Shield on/off 토글 리소스가 없다. 유일한 쓰기 리소스
    `cloudflare_page_shield_policy`는 Content Security Rules(Advanced 애드온)용이라 Free 플랜에서는
    apply가 실패한다. 그래서 이 설정만 Terraform 밖에서 관리한다.
  - 활성화: 대시보드 Security → Settings → Client-side security에서 켜거나
    `PUT /zones/{zone_id}/page_shield {"enabled": true}`를 호출한다.
  - Free 플랜은 script 모니터링만 제공한다. connection·cookie 모니터링과 알림은 Business+, 차단(Content
    Security Rules)은 Advanced 애드온이므로 `cloudflare_page_shield_policy`는 Free에서 추가하지 않는다.
  - 필요하면 read-only data source(`cloudflare_page_shield_scripts_list` 등)로 관찰된 스크립트
    인벤토리를 CI에서 스냅샷해 신규 3rd-party 스크립트를 감지할 수 있다(선택).
- Certificate Transparency Monitoring — **활성화됨(2026-07 수동)**: 공개 CT 로그에 sobok.cc 인증서가
  발급되면 메일로 알리는 rogue·오발급 인증서 조기경보다. 응답 동작을 바꾸지 않고 무료이지만 provider v5에
  리소스가 없어 Terraform 밖에서 관리한다 (`cloudflare_notification_policy`에 CT용 alert_type이 없고
  provider #2842는 미구현으로 close, zone setting도 아님).
  - 활성화: 대시보드 SSL/TLS → Edge Certificates → Certificate Transparency Monitoring, 또는
    `PATCH /zones/{zone_id}/ct/alerting {"enabled": true}`(Free/Pro는 `enabled`로 토글).
  - Free 플랜은 계정 멤버 전원에게 메일이 가고 수신자를 지정할 수 없다. 정상 재발급·백업 인증서도 메일이
    오므로 "정상 vs 의심" 기준을 팀에 공유한다. 예방책으로 CAA DNS 레코드를 dns 워크스페이스에 병행할 수 있다.
- Precursor — **활성화됨(2026-07 수동)**: 세션 기반 봇 탐지. provider v5 리소스가 없어 TF 관리 불가이며,
  Cloudflare는 이를 Enterprise Bot Management 기능으로 안내하므로 Free에서 활성 상태가 유지되지 않을 수 있다
  (GA 전 무료 베타 잔여 토글일 가능성). Bot Fight Mode + Turnstile과 기능이 겹친다.
- Crawler Hints: cache flags 엔드포인트(`/flags/products/cache/changes`, zone setting이 아님)라 provider v5로
  관리할 수 없다. IndexNow SEO 신호이고 인증 앱엔 가치가 낮아 기본 off를 유지한다.

## 의도적으로 baseline에서 제외한 기능

- Rocket Loader: 모든 JS를 지연·재정렬해 React/better-auth SPA의 hydration을 깨므로 baseline에서
  제외한다. 켜야 한다면 `manual` 모드로 script별 opt-in한다. (Hotlink Protection·Always Online·Cloudflare
  Fonts는 `settings`에서 명시적으로 소유한다 — 각각 off·on·on. Always Online은 IA Supplemental Terms
  동의가 선행돼야 한다.)
- AI 봇 하드 차단(`ai_bots_protection`, "Block AI bots"): 콘텐츠 정책이라 서비스 공통 보안 baseline에
  넣지 않는다. (AI Labyrinth는 `crawler_protection`, managed robots.txt는 `is_robots_txt_managed`로 security의
  bot_management가 소유한다. crawler_protection의 Free 수용 여부는 첫 plan/apply로 확인하고, apex의 AdSense
  크롤러 영향도 모니터링한다.)
- `pq_keyex`: 현재 Cloudflare는 모든 proxied TLS 1.3 연결에 hybrid post-quantum key agreement를
  기본 제공하므로 legacy Zone 토글을 별도로 소유하지 않는다.
- `0rtt` 별도 토글: 0-RTT("resumed connections for returning visitors")은 `tls_1_3 = "zrt"`로 이미
  켜져 있어 별도 `0rtt` Zone 토글을 소유하지 않는다. 두 설정은 커플링돼 있어 중복 토글은 perpetual
  diff를 만든다(provider #7118).
- Leaked Credential 엣지 mitigation: Free 플랜은 custom detection location과 Log 액션이 Enterprise
  전용이고 `password_leaked`(비밀번호 전용)만 노출해 custom better-auth 로그인 엔드포인트에서 신뢰성
  있게 동작하지 않는다. credential stuffing 방어는 애플리케이션(better-auth의 HIBP k-anonymity 검사)과
  기존 Turnstile로 처리하고, 엣지 mitigation 규칙은 유료 플랜 전환 시 `security`에 detection과 함께
  추가한다. detection 토글 자체는 `security/leaked-credentials.tf`가 선언한다.

## 참고

- [Cloudflare SSL/TLS 시작 가이드](https://developers.cloudflare.com/ssl/get-started/)
- [Cloudflare Bot Fight Mode](https://developers.cloudflare.com/bots/get-started/bot-fight-mode/)
- [Cloudflare DNSSEC](https://developers.cloudflare.com/dns/dnssec/)
- [Cloudflare Managed Transforms](https://developers.cloudflare.com/rules/transform/managed-transforms/)
- [Cloudflare Page Shield](https://developers.cloudflare.com/page-shield/)
- [Cloudflare Speed Brain](https://developers.cloudflare.com/speed/optimization/content/speed-brain/)
- [Cloudflare Leaked Credential Detection](https://developers.cloudflare.com/waf/detections/leaked-credentials/)
- [Cloudflare 0-RTT Connection Resumption](https://developers.cloudflare.com/speed/optimization/protocol/0-rtt-connection-resumption/)
- [Cloudflare URL Normalization](https://developers.cloudflare.com/rules/normalization/)
- [Cloudflare Fonts](https://developers.cloudflare.com/speed/optimization/content/fonts/)
- [Cloudflare Certificate Transparency Monitoring](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/certificate-transparency-monitoring/)
- [HCP Terraform workspace best practices](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/best-practices)
- [Terraform removed block](https://developer.hashicorp.com/terraform/language/block/removed)
- [PortOne V2 webhook](https://developers.portone.io/opi/ko/integration/webhook/readme-v2?v=v2)
