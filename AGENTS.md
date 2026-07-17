# AGENTS.md

## 협업

- 도중에 결정이 필요하거나 애매한 부분이나 맥락을 모르거나 궁금한 점이 있으면 먼저 질문한다.
- 이 repo의 아키텍처 기본값을 바꾸는 변경은 사용자 확인 없이 진행하지 않는다.
- 구조 변경 전에는 관련 문서를 먼저 읽고, 문서와 충돌하면 먼저 질문한다.
- 개별 폴더를 작업할 땐 해당 폴더의 AGENTS.md 파일을 읽는다.

## 레포 역할

- 이 repo는 sobok 프로덕션의 desired state를 관리한다. 앱 소스 코드는 sibling repo `../sobok`에 있다.
- 상태 저장 데이터(Postgres/Valkey/Kafka)는 전부 Aiven 매니지드다. 박스에는 stateless 앱만 돈다.

## 레포 규칙

- 이 repository는 public repo다.
- 커밋되는 모든 파일은 공개될 수 있다고 가정한다.
- secret, token, private key, credential, 계정 정보, 민감한 운영 정보는 커밋하지 않는다.

## Cloudflare

- Cloudflare는 Free plan을 사용한다.
- Cloudflare 관련 보안/캐시/라우팅 제안은 Free plan에서 가능한 기능을 우선 고려한다.
