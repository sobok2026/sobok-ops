# Cloudflare 인프라

Cloudflare 프로덕션 상태는 HCP Terraform `sobok` 조직의 `cloudflare` 프로젝트에서 관리한다.
이 레포가 source of truth이며 Dashboard 변경은 break-glass 용도로만 사용하고 즉시 Terraform에
반영한다.

## 워크스페이스

| 경로 | HCP Terraform 워크스페이스 | 소유 범위 |
| --- | --- | --- |
| `account/sobok/workers` | `account-workers` | stella, horn, zwds Worker와 custom domain |
| `account/sobok/vibe` | `account-vibe` | vibe Worker custom domain, Hyperdrive, Secrets Store |
| `account/sobok/tunnel` | `account-selfhost-tunnel` | production cloudflared tunnel과 ingress |
| `account/sobok/turnstile` | `account-turnstile` | 공유 Turnstile widget |
| `zone/sobok.cc/settings` | `zone-sobok-cc-settings` | 저변동 Zone baseline, Universal SSL, Managed Transforms |
| `zone/sobok.cc/security` | `zone-sobok-cc-security` | Bot Fight Mode와 PortOne webhook 선행 허용 규칙 |
| `zone/sobok.cc/dns` | `zone-sobok-cc-dns` | DNSSEC와 향후 명시적으로 관리할 DNS 레코드 |

워크스페이스는 값의 자료형이나 Dashboard 메뉴가 아니라 상태 소유권과 변경 위험으로 나눈다.

- 모든 `cloudflare_zone_setting`은 값이 on/off, enum, 숫자, 객체 중 무엇이든 `settings` 한 곳에서
  소유한다. SSL/TLS 설정을 별도 state에서도 소유하게 만들지 않는다.
- Universal SSL과 Managed Transforms는 같은 저변동 baseline이므로 `settings`의 별도 `.tf` 파일로
  둔다. 리소스 종류마다 워크스페이스를 만들지 않는다.
- Bot Fight Mode와 PortOne IP 허용 규칙은 함께 적용·롤백되어야 하므로 `security`가 같이 소유한다.
- DNSSEC은 registrar 위임 상태와 롤백 순서가 있어 `dns`로 격리한다. Worker custom domain이 자동으로
  만든 DNS 레코드는 해당 account 워크스페이스가 계속 소유하며 `dns`에 중복 선언하지 않는다.
- Ruleset이 필요해지면 `rulesets/waf-custom`, `rulesets/rate-limit`, `rulesets/cache`,
  `rulesets/redirects`처럼 **Cloudflare phase별** root를 그때 추가한다. 한 phase의 entry-point
  ruleset을 여러 state가 나누어 소유하지 않는다.

## HCP Terraform 설정

세 Zone 워크스페이스를 VCS-driven, manual apply로 만들고 위 표의 경로를 working directory로
지정한다. pull request는 speculative plan을 실행하고 main 반영 후 apply는 명시적으로 승인한다.

프로젝트 변수 세트에 다음 환경 변수를 둔다.

| 키 | 종류 | Sensitive |
| --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | Environment | Yes |

토큰은 `sobok.cc` Zone으로 resource scope를 제한하고 워크스페이스가 사용하는 최소 권한만 부여한다.

| 워크스페이스 | 필요한 권한 |
| --- | --- |
| `zone-sobok-cc-settings` | Zone Read, Zone Settings Read/Write, SSL and Certificates Read/Write, Managed Headers Read/Write |
| `zone-sobok-cc-security` | Zone Read, Bot Management Read/Write, Account Firewall Access Rules Read/Write |
| `zone-sobok-cc-dns` | Zone Read, DNS Read/Write |

별도 Terraform 변수는 필요 없다. `domain`의 기본값은 `sobok.cc`이며 account/zone ID는 Zone 조회에서
파생한다.

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

## 의도적으로 baseline에서 제외한 기능

- Always Online: Internet Archive에 인기 URL을 전달하고 origin 장애 시 보관본을 제공하므로
  transactional·authenticated 애플리케이션의 범용 baseline으로 사용하지 않는다.
- Hotlink Protection, Rocket Loader, Cloudflare Fonts: 응답 또는 외부 임베딩 동작을 바꾸므로 실제
  요구가 생겼을 때 hostname/path 범위로 검토한다.
- AI crawler 차단, AI Labyrinth, managed `robots.txt`: 콘텐츠 배포 정책이지 서비스 공통 보안
  baseline이 아니다.
- `pq_keyex`: 현재 Cloudflare는 모든 proxied TLS 1.3 연결에 hybrid post-quantum key agreement를
  기본 제공하므로 legacy Zone 토글을 별도로 소유하지 않는다.
- Add visitor location headers: 애플리케이션이 사용하지 않는 세부 위치 헤더를 origin에 추가하지
  않는다. 국가 코드는 Cloudflare의 표준 `CF-IPCountry`를 필요할 때 사용한다.

## 참고

- [Cloudflare SSL/TLS 시작 가이드](https://developers.cloudflare.com/ssl/get-started/)
- [Cloudflare Bot Fight Mode](https://developers.cloudflare.com/bots/get-started/bot-fight-mode/)
- [Cloudflare DNSSEC](https://developers.cloudflare.com/dns/dnssec/)
- [Cloudflare Managed Transforms](https://developers.cloudflare.com/rules/transform/managed-transforms/)
- [HCP Terraform workspace best practices](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/best-practices)
- [PortOne V2 webhook](https://developers.portone.io/opi/ko/integration/webhook/readme-v2?v=v2)
