# sobok-ops

sobok 프로덕션의 desired state 저장소. 앱 소스는 sibling repo [`../sobok`](https://github.com/sobok2026/sobok)에 있다.

## 아키텍처

```
Mac Mini (macOS — 역할: 부팅 + LaunchDaemon뿐. FileVault 잠금해제 후엔 로그인 불필요)
└─ QEMU/HVF VM — root LaunchDaemon org.sobok.vm (10 CPU / 12 GiB / raw 60 GiB, vmnet NAT)
   └─ Talos Linux 단일 노드 Kubernetes (SSH 없음, talosctl API 관리, tailscale 확장으로 원격 관리)
      ├─ Flux — 이 레포의 kubernetes/를 pull·reconcile, SOPS(age) 복호화
      ├─ Envoy Gateway ← cloudflared (outbound 터널, 인바운드 포트 0)
      └─ web · api · chat · chat-worker · chat-push (Deployment) + billing-worker (CronJob)
데이터는 전부 클러스터 밖: Aiven PG/Valkey/Kafka, CockroachDB Cloud → 클러스터는 소모품
```

호스트 스택은 Talos 공식 macOS QEMU 프로비저너(`talosctl cluster create qemu`)와 동일한
Homebrew QEMU + HVF + vmnet-shared 조합이고 VM 수명주기만 launchd로 직접 관리한다.
게스트 재부팅은 `-no-reboot`로 QEMU 종료가 되고 launchd가 재기동한다 — Talos 업그레이드의
A/B 재부팅과 크래시 복구가 같은 경로로 처리된다.

## 레포 구조

| 경로               | 역할                                                                                                                                                     |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `host/`            | Mac mini 호스트 레이어. VM 선언(vm.env)·QEMU 래퍼·LaunchDaemon plist·설치/워치독 스크립트. 매니지드 이관 시 talos/와 함께 버린다                         |
| `talos/`           | 머신 레이어. talhelper 선언(talconfig/talenv) + SOPS 머신 시크릿. 매니지드 k8s 이관 시 버리는 층                                                         |
| `bootstrap/`       | sops-age Secret 암호문 — `just seal-age-key` 산출물(런북 6단계, 최초 1회 생성·커밋). 클러스터 생성마다 1회 수동 apply하는 유일한 파일 (이관 시에도 필요) |
| `kubernetes/flux/` | Flux 진입점. `flux bootstrap` 산출물(`flux-system/`)과 루트 Kustomization(`cluster/ks.yaml` → `kubernetes/apps/` 재귀 리컨실)                            |
| `kubernetes/apps/` | 앱 매니페스트. `<네임스페이스>/<앱>/{ks.yaml,app/}` 콜로케이션 — 3~4단계에서 추가 예정                                                                   |
| `infra/`           | Terraform (Aiven·Cloudflare·Grafana Cloud·GTM). state는 HCP Terraform 원격                                                                               |

규칙: 이 레포는 public이다. 비밀은 반드시 `*.sops.yaml` 암호문으로만 커밋한다. `talos/clusterconfig/`는 평문 비밀이라 절대 커밋하지 않는다(gitignore + talhelper 자동 gitignore 이중 방어).

## 외부 상태 (레포 밖에 존재하는 전부)

이 레포 + 아래 항목만 있으면 전체 복구가 된다.

1. **age 개인키** — `~/Library/Application Support/sops/age/keys.txt`. 오프라인 백업 필수. 분실 시 복구 불가(아래 "age 키 분실" 참고)
2. **GitHub PAT** — `flux bootstrap`용 repo 스코프. flux가 만드는 deploy key는 자동 관리됨
3. **HCP Terraform 계정** — infra/ state 백엔드
4. GHCR read:packages 토큰 — 4단계(워크로드)에서 pull secret 원본으로 사용

tailscale OAuth 시크릿과 터널 credential 등 나머지 비밀은 전부 age로 암호화되어 레포 안에 있다.

## 운영

### 앱 롤백

기본 절차는 **전진 롤백**: sobok 레포에서 원인 커밋을 `git revert`하면 CI가 더 높은 epoch의 새 태그를 빌드·승격한다. 주의 두 가지:

- 승격 커밋을 이 레포에서 revert하는 건 무효다 — image automation이 5분 안에 같은 태그를 재승격한다. 급할 땐 `flux suspend image update sobok`으로 자동화를 먼저 멈추고 revert한 뒤 원인 해소 후 resume한다
- `kubectl rollout undo` 금지 — ConfigMap이 해시 서픽스로 관리되어 옛 리비전의 CM은 이미 prune됐다
- sobok main의 force-push 롤백 금지 — 태그의 단조 축이 커밋 epoch라 히스토리를 되감으면 새 커밋의 epoch가 이미 승격된 태그보다 낮아져 승격이 조용히 멈춘다 (다음 정상 커밋이 추월하면 자연 해소)

### 업그레이드

```bash
# talos/talenv.yaml에서 talosVersion 올리고
just talos-upgrade      # 같은 스키마틱 ID의 installer로 업그레이드 → tailscale 확장 유지
# kubernetesVersion 올리고
just talos-upgrade-k8s
```

주의: 스키마틱이 다른 이미지로 업그레이드하면 tailscale 확장이 사라져 원격 접근을 잃는다. 반드시 talhelper 생성 명령(`just talos-upgrade`)을 쓴다. 업그레이드의 A/B 재부팅은 QEMU 종료 → launchd 재기동으로 자동 처리된다.

### 호스트 운영 (Mac mini)

- **계획 재부팅**: `just host-restart` — VM을 정상 종료한 뒤 `fdesetup authrestart`로 다음 부팅의 FileVault 잠금해제를 1회 생략한다. **정전·패닉 후엔 잠금해제 화면에서 멈추므로 물리 접근이 필요하다** (`pmset autorestart`가 켜져 있어 전원 복구 시 부팅 자체는 시작된다)
- **macOS 업데이트**: 자동 설치는 host-prep이 차단한다. 유지보수 윈도우에 `just vm-stop` → 업데이트 → `just host-restart`. 메이저 업그레이드는 QEMU·vmnet 호환 리포트를 확인한 뒤 올린다
- **QEMU 업그레이드**: `brew pin qemu`로 우발적 업그레이드를 막고 유지보수 윈도우에만 unpin·upgrade 후 `just vm-restart`
- **워치독**: 5분마다 QEMU 프로세스·Talos API(50000)·K8s API(6443)·호스트 디스크·메모리 압력을 점검하고 상태 전이 시 Discord로 알린다. 웹훅은 `/opt/sobok/vm/discord-webhook`(root 전용 파일)에 저장하며 flux 알림과 같은 웹훅을 재사용해도 된다. 로그: `/opt/sobok/vm/log/watchdog.log`
- **시리얼 로그**: `/opt/sobok/vm/log/serial.log`. VM 시작 시 50 MB 초과분은 `.old`로 로테이션된다

### age 키 분실 시

암호문 복호화가 영구 불가능해진다. 절차: 새 키 생성 → `.sops.yaml` 공개키 교체 → 원본이 남아 있는 비밀(Aiven·Cloudflare·Grafana·tailscale·Discord)을 전부 재발급해 재암호화 커밋 → `talos/talsecret.sops.yaml`은 재생성 불가하므로 클러스터도 재설치. 오프라인 백업이 이 전체를 막는다.

### 매니지드 k8s 이관 체크리스트

1. `host/`·`talos/`와 justfile의 host-\*·vm-\*·talos-\* 레시피 삭제
2. metrics-server의 `--kubelet-insecure-tls` 제거 (또는 앱 자체 삭제)
3. EnvoyProxy replicas 상향 (단일 노드 흔적)
4. `bootstrap/`은 유지 — 새 클러스터에도 sops-age 주입(`flux-up`)은 그대로 필요하다
