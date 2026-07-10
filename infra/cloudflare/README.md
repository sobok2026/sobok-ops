# Cloudflare 인프라

Cloudflare 는 HCP Terraform 의 `sobok` 조직, `cloudflare` 프로젝트에서 관리한다. 이 레포가
desired-state 소스다; Cloudflare 대시보드 변경은 break-glass(긴급) 용도에 한하며, 즉시 Terraform 으로
다시 수렴시켜야 한다.

## 워크스페이스

| 레포 경로                              | HCP Terraform 워크스페이스          | 범위                                |
| -------------------------------------- | ----------------------------------- | ----------------------------------- |
| `./account/sobok/selfhost-tunnel`     | `account-selfhost-tunnel`           | 계정 레벨 Cloudflare Tunnel         |
| `./account/sobok/turnstile`           | `account-turnstile`                 | 계정 레벨 Turnstile 위젯            |
| `./zone/sobok.cc/dns`                 | `zone-sobok-cc-dns`                | 존 DNS 레코드                       |
| `./zone/sobok.cc/bot-management`      | `zone-sobok-cc-bot-management`     | Bot Management 설정                 |
| `./zone/sobok.cc/rulesets/cache`      | `zone-sobok-cc-cache`              | Cache Rules 페이즈                  |
| `./zone/sobok.cc/rulesets/rate-limit` | `zone-sobok-cc-rate-limit`         | Rate limiting 페이즈               |
| `./zone/sobok.cc/rulesets/redirects`  | `zone-sobok-cc-redirects`          | Dynamic redirects 페이즈           |
| `./zone/sobok.cc/rulesets/waf-custom` | `zone-sobok-cc-waf-custom`         | WAF custom rules 페이즈            |
| `./zone/sobok.cc/ssl-tls`             | `zone-sobok-cc-ssl-tls`            | SSL/TLS 엣지 설정                   |
| `./zone/sobok.cc/managed-transforms`  | `zone-sobok-cc-managed-transforms` | Managed transforms                  |
| `./zone/sobok.cc/settings`            | `zone-sobok-cc-settings`           | Speed, Scrape Shield, Security      |

각 워크스페이스는 VCS 기반 실행 + 수동 apply 를 쓴다. Pull request 는 speculative plan 을 만들고,
프로덕션 브랜치 병합은 HCP Terraform 에서 명시적 apply 승인을 요구해야 한다.

## 워크스페이스 변수

프로바이더 자격증명을 위한 프로젝트 레벨 변수 세트를 만든다:

| 종류        | 키                     | 민감 | 비고                               |
| ----------- | ---------------------- | ---- | ---------------------------------- |
| Environment | `CLOUDFLARE_API_TOKEN` | Yes  | Cloudflare 프로바이더 인증         |

계정 레벨 워크스페이스용 변수 세트를 만든다:

| 종류      | 키           | 민감 | 비고                            |
| --------- | ------------ | ---- | ------------------------------- |
| Terraform | `account_id` | No   | `account-*` 워크스페이스에 적용 |

`sobok.cc` 존 워크스페이스용 변수 세트를 만든다:

| 종류      | 키        | 민감 | 비고                                    |
| --------- | --------- | ---- | --------------------------------------- |
| Terraform | `zone_id` | No   | `zone-sobok-cc-*` 워크스페이스에 적용   |

`zone-sobok-cc-waf-custom` 에 이 워크스페이스별 Terraform 변수를 설정한다:

| 종류      | 키                   | 민감 | HCL | 비고                     |
| --------- | -------------------- | ---- | --- | ------------------------ |
| Terraform | `blocked_source_ips` | No   | Yes | 소스 IP 의 HCL 리스트    |

`zone-sobok-cc-rate-limit` 에 이 워크스페이스별 Terraform 변수들을 설정한다:

| 종류      | 키                    | 민감 | 비고                                    |
| --------- | --------------------- | ---- | --------------------------------------- |
| Terraform | `rate_limit_period`   | Yes  | Rate limiting 기간(초)                  |
| Terraform | `rate_limit_requests` | Yes  | 기간당 허용 최대 요청 수                |
| Terraform | `rate_limit_timeout`  | Yes  | 한도 초과 후 완화(mitigation) 타임아웃  |

## 워크스페이스 간 의존성

`zone/sobok.cc/dns` 는 `account-selfhost-tunnel` 의 `selfhost_tunnel_cname` 을
`terraform_remote_state` 로 읽는다. DNS 를 plan 하기 전에 HCP Terraform 에서 DNS 워크스페이스가
tunnel 워크스페이스의 state 출력을 읽을 수 있도록 허용한다. 전역 remote-state 접근이 아니라 DNS
워크스페이스에만 부여하는 것을 선호한다.

## 운영 규칙

- 로컬 `.tfvars` 나 `.env` 파일로 Cloudflare 변경을 실행하지 않는다.
- 로컬 `terraform.tfstate` 를 권위 소스로 쓰지 않는다.
- 평상시 운영 중에 대시보드에서 Cloudflare 리소스를 편집하지 않는다.
- break-glass 복구를 위해 대시보드 변경이 필요했다면, 다음 정상 apply 전에 Terraform 으로 import/갱신한다.
- 넓은 공유 state 를 키우기보다, 새 제품이나 페이즈는 새 워크스페이스로 추가하는 것을 선호한다.
