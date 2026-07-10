# Grafana Cloud 인프라

Grafana Cloud 는 HCP Terraform 의 `sobok` 조직에서 관리한다. 이 레포가 source of truth 다; UI 변경은
break-glass 용도에 한하며 Terraform 으로 다시 수렴시켜야 한다.

Terraform 이 Grafana Cloud **설정**을 소유한다: 스택, access policy 와 토큰, 스택 서비스 계정,
알림(contact point, notification policy, SLO), Synthetic Monitoring 체크, Frontend Observability 앱,
폴더, 대시보드.

텔레메트리 **수집**은 별도 컬렉터가 아니라, Mac Mini 의 앱 컨테이너가 OTLP 를 Grafana Cloud 로 직접
전송한다(compose 서비스의 `OTEL_EXPORTER_OTLP_ENDPOINT`/`OTEL_EXPORTER_OTLP_HEADERS`, secrets 참고).

**관리 대상 아님:** Grafana 앱이 자동 프로비저닝하는 콘텐츠 — Asserts / Synthetic Monitoring / k6 /
App Observability 대시보드, 통합(integration)이 함께 배포하는 alert/recording 규칙. 이를 import 하면
영구적인 drift 가 생긴다.

## 워크스페이스

| 경로     | HCP 워크스페이스     | 프로젝트  | 범위                                                                                                 |
| -------- | -------------------- | --------- | ---------------------------------------------------------------------------------------------------- |
| `cloud/` | `grafana-cloud`      | `grafana` | 스택, access policy + 토큰, 스택 서비스 계정, Synthetic Monitoring, Frontend Observability            |
| `stack/` | `grafana-stack-prod` | `grafana` | Contact point, notification policy, SLO, 폴더, 대시보드                                               |

## 사전 조건

- **Grafana Cloud 계정**(org)이 존재한다. slug 와 access policy 토큰을 만들 권한만 있으면 되고 —
  스택과 그 밖의 모든 것은 Terraform 이 생성한다.

## 셋업

1. HCP 프로젝트 `grafana` 와 두 워크스페이스(VCS 기반, 수동 apply)를 만든다:
   - `grafana-cloud` → 작업 디렉터리 `infra/grafana/cloud`
   - `grafana-stack-prod` → 작업 디렉터리 `infra/grafana/stack`
2. Grafana Cloud 포털에서 **Access Policy 토큰**(org realm)을 만든다. 스코프: `stacks:read`,
   `stacks:write`, `accesspolicies:read`, `accesspolicies:write`, `stack-service-accounts:write`,
   그리고 Synthetic Monitoring / Frontend Observability 스코프. 이를 `grafana-cloud` 워크스페이스 변수
   `grafana_cloud_access_policy_token`(sensitive)으로 설정한다.
3. `grafana-cloud` 변수(아래)를 설정하고 **apply**. 스택, 컬렉터 토큰, 스택 서비스 계정,
   Synthetic Monitoring, Frontend Observability 앱을 생성한다.
4. `grafana-stack-prod`: Discord 웹훅을 설정하고, `grafana-cloud` 에 대한 remote-state 읽기를 부여한 뒤
   **apply**. contact point, notification policy, SLO, 폴더를 생성한다.

## 변수

아래 값은 모두 **워크스페이스 변수**(Terraform 종류)로 설정한다.

`grafana-cloud`:

| 키                                  | 민감 | 비고                                             |
| ----------------------------------- | ---- | ------------------------------------------------ |
| `grafana_cloud_access_policy_token` | Yes  | 부트스트랩용 org access policy 토큰              |
| `grafana_cloud_organization_slug`   | No   | Grafana Cloud org slug                           |
| `grafana_stack_slug`                | No   | 생성할 스택 서브도메인(`<slug>.grafana.net`)     |

`grafana-stack-prod`:

| 키                             | 민감 | 비고                        |
| ------------------------------ | ---- | --------------------------- |
| `discord_critical_webhook_url` | Yes  | Critical + 기본 채널        |
| `discord_warning_webhook_url`  | Yes  | `severity=warning` 채널     |

## 워크스페이스 간 remote state

`grafana-stack-prod` 는 `grafana-cloud` 출력을 `terraform_remote_state` 로 읽는다. `grafana-cloud`
워크스페이스에서 이를 승인된 remote state consumer 로 추가한다 — 전역 접근이 아니라.

## apply 이후

- **수집:** 앱 컨테이너의 OTLP 설정(`OTEL_EXPORTER_OTLP_ENDPOINT`/`OTEL_EXPORTER_OTLP_HEADERS`)에
  이 스택의 ingest URL 과 컬렉터 토큰(`grafana-cloud` 출력)을 넣는다. 값은 SOPS 시크릿으로 관리한다.
- **Frontend Observability:** web 앱의 Faro SDK 컬렉터 URL 을 `frontend_o11y_collector_endpoint`
  출력값으로 설정한 뒤 재배포한다.
