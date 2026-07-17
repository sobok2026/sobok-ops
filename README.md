# sobok-ops

sobok 프로덕션의 desired state 저장소. 앱 소스는 sibling repo [`../sobok`](https://github.com/sobok2026/sobok)에 있다.

## 아키텍처

```
Mac Mini (macOS — 역할: 부팅 + UTM 자동 시작뿐)
└─ UTM vz headless VM (10 CPU / 12 GiB / raw 60 GiB)
   └─ Talos Linux 단일 노드 Kubernetes (SSH 없음, talosctl API 관리, tailscale 확장으로 원격 관리)
      ├─ Flux — 이 레포의 kubernetes/를 pull·reconcile, SOPS(age) 복호화
      ├─ Envoy Gateway ← cloudflared (outbound 터널, 인바운드 포트 0)
      └─ web · api · chat · chat-worker · chat-push (Deployment) + billing-worker (CronJob)
데이터는 전부 클러스터 밖: Aiven PG/Valkey/Kafka, CockroachDB Cloud → 클러스터는 소모품
```

## 레포 구조

| 경로 | 역할 |
|---|---|
| `talos/` | 머신 레이어. talhelper 선언(talconfig/talenv) + SOPS 머신 시크릿. 매니지드 k8s 이관 시 버리는 유일한 층 |
| `bootstrap/` | sops-age Secret 암호문. 클러스터 생성마다 1회 수동 apply하는 유일한 파일 (이관 시에도 필요) |
| `kubernetes/` | Flux 진입점(`flux/`)과 앱 매니페스트(`apps/<네임스페이스>/<앱>/`) — 2~4단계에서 추가 예정 |
| `infra/` | Terraform (Aiven·Cloudflare·Grafana Cloud·GTM). state는 HCP Terraform 원격 |

규칙: 이 레포는 public이다. 비밀은 반드시 `*.sops.yaml` 암호문으로만 커밋한다. `talos/clusterconfig/`는 평문 비밀이라 절대 커밋하지 않는다(gitignore + talhelper 자동 gitignore 이중 방어).

## 외부 상태 (레포 밖에 존재하는 전부)

이 레포 + 아래 항목만 있으면 전체 복구가 된다.

1. **age 개인키** — `~/Library/Application Support/sops/age/keys.txt`. 오프라인 백업 필수. 분실 시 복구 불가(아래 "age 키 분실" 참고)
2. **GitHub PAT** — `flux bootstrap`용 repo 스코프. flux가 만드는 deploy key는 자동 관리됨
3. **HCP Terraform 계정** — infra/ state 백엔드
4. GHCR read:packages 토큰 — 4단계(워크로드)에서 pull secret 원본으로 사용

tailscale OAuth 시크릿과 터널 credential 등 나머지 비밀은 전부 age로 암호화되어 레포 안에 있다.

## 부트스트랩 런북

새 Mac(관리 머신)이든 새 VM(DR)이든 순서는 같다. 소요 시간은 VM 생성 포함 30분 내외.

### 0. 도구

```bash
mise install   # .mise.toml 버전 핀 그대로 설치
```

### 1. age 키와 SOPS

```bash
just age-keygen   # 키 생성(있으면 스킵) + 공개키 출력
```

- 출력된 공개키(`age1...`)로 `.sops.yaml`의 `<AGE_PUBLIC_KEY>` 두 곳을 교체한다 (최초 1회)
- 개인키 파일을 오프라인 백업한다 (DR의 뿌리)
- DR 시나리오(키가 이미 있는 경우): 백업한 keys.txt를 위 경로에 복원만 하면 된다

### 2. tailscale 시크릿 (최초 1회)

[Tailscale admin console](https://login.tailscale.com/admin/settings/oauth)에서 OAuth client를 만든다 — scope `auth_keys`, 태그 `tag:sobok`. 태그는 먼저 ACL 정책 파일의 `tagOwners` 블록에 `"tag:sobok": ["autogroup:admin"]`으로 선언해야 한다. OAuth secret은 만료가 없어 authkey 90일 만료 문제를 피한다.

```bash
cd talos && sops talenv.sops.yaml   # 새 파일이 에디터로 열림
```

```yaml
TAILSCALE_AUTHKEY: tskey-client-xxxxx?ephemeral=false&preauthorized=true
```

`ephemeral=false`가 중요하다. 기본값 true면 노드가 오프라인일 때 tailnet에서 자동 삭제된다.

### 3. UTM VM 생성

| 항목 | 값 |
|---|---|
| 백엔드 | Apple Virtualization (vz) |
| CPU / RAM | 10 코어 / 12 GiB |
| 디스크 | 60 GiB (raw, APFS sparse라 실사용량만 차지) |
| 네트워크 | Shared Network + **MAC 고정 `f2:50:b0:0c:00:01`** (justfile `vm_mac`과 일치) |
| 디스플레이 | 삭제 (headless) |
| 시리얼 | Pseudo-TTY 모드 1개 유지. VM 상세에 표시되는 `/dev/ttysNNN` 경로로 `screen /dev/ttysNNN` 접속 (maintenance IP 확인·비상 콘솔) |
| 부팅 ISO | `just talos-iso-url` 출력 URL에서 다운로드 (tailscale 확장 + hvc0 콘솔 + arm64가 구워진 스키마틱 — `metal-arm64.iso`인지 확인) |

- UTM.app은 데몬이 아니라 앱이다. 로그인 항목에 UTM을 추가하고 `utmctl start <VM이름>`을 실행하는 로그인 스크립트(Automator 앱 또는 Shortcuts)를 등록한다. 로그인 직후 UTM 초기화 전이면 실패하므로 재시도를 넣는다
- Mac 설정: 자동 로그인 활성 + 전원 복구 시 자동 시작 + 잠자기 금지
- 정적 IP `.10`을 macOS DHCP 동적 풀에서 보호한다: `/etc/bootptab`에 `sobok-1 1 f2:50:b0:0c:00:01 192.168.64.10` 예약을 넣고 `sudo launchctl kickstart -kp system/com.apple.bootpd`로 리로드
- 서브넷 드리프트 주의: macOS가 lease 기록 기준으로 공유 네트워크 대역을 바꿀 수 있다. `/Library/Preferences/SystemConfiguration/com.apple.vmnet.plist`의 `Shared_Net_Address`가 `192.168.64.1`인지 확인하고 다르면 고정한다

### 4. Talos 설치

```bash
just talos-secret            # 머신 시크릿 생성 + SOPS 봉인 (최초 1회, DR 시엔 기존 파일 재사용)
just talos-genconfig         # clusterconfig/ 생성 (커밋 금지 대상)
just vm-ip                   # VM 부팅 후 maintenance mode DHCP IP 확인 (또는 시리얼 콘솔)
# 이 시점에 디스크/NIC 실측 확인 권장:
#   talosctl -n <maintenance-ip> get disks --insecure   → /dev/vda 확인
#   talosctl -n <maintenance-ip> get links --insecure   → virtio_net 확인
just talos-apply-first <maintenance-ip>   # 설치 시작 → 재부팅 후 정적 IP 192.168.64.10
just talos-bootstrap         # etcd 부트스트랩 (성공까지 자동 재시도)
just talos-kubeconfig        # ~/.kube/config 병합
just talos-health
```

노드가 tailnet에 조인하면 talconfig.yaml의 certSANs 주석 두 곳(`sobok-1.<tailnet>.ts.net` — 노드 `certSANs`와 `additionalApiServerCertSans`)을 해제하고 `just talos-genconfig && just talos-apply`로 재적용한다. 이후 어디서든 tailnet 경유 talosctl/kubectl이 된다.

DR 재설치 시에는 admin console에서 기존 `sobok-1` 머신을 먼저 삭제한다. 남아 있으면 새 노드가 `sobok-1-1`로 밀려나 certSANs의 MagicDNS 이름과 어긋난다.

### 5. Flux 설치

```bash
just seal-age-key            # age 키 → bootstrap/sops-age.sops.yaml 암호문 (최초 1회)
export GITHUB_TOKEN="$(gh auth token)"   # 또는 생략 — flux-up이 프롬프트로 받는다 (인라인 할당은 셸 히스토리에 남으니 금지)
just flux-up
```

`flux bootstrap`은 멱등이라 재실행해도 안전하다. 이후는 전부 GitOps — `kubernetes/`에 커밋하면 Flux가 수렴시킨다.

## 운영

### 업그레이드

```bash
# talos/talenv.yaml에서 talosVersion 올리고
just talos-upgrade      # 같은 스키마틱 ID의 installer로 업그레이드 → tailscale 확장 유지
# kubernetesVersion 올리고
just talos-upgrade-k8s
```

주의: 스키마틱이 다른 이미지로 업그레이드하면 tailscale 확장이 사라져 원격 접근을 잃는다. 반드시 talhelper 생성 명령(`just talos-upgrade`)을 쓴다.

### age 키 분실 시

암호문 복호화가 영구 불가능해진다. 절차: 새 키 생성 → `.sops.yaml` 공개키 교체 → 원본이 남아 있는 비밀(Aiven·Cloudflare·Grafana·tailscale·Discord)을 전부 재발급해 재암호화 커밋 → `talos/talsecret.sops.yaml`은 재생성 불가하므로 클러스터도 재설치. 오프라인 백업이 이 전체를 막는다.

### 매니지드 k8s 이관 체크리스트

1. `talos/`와 justfile의 talos-* 레시피 삭제
2. metrics-server의 `--kubelet-insecure-tls` 제거 (또는 앱 자체 삭제)
3. EnvoyProxy replicas 상향 (단일 노드 흔적)
4. `bootstrap/`은 유지 — 새 클러스터에도 sops-age 주입(`flux-up`)은 그대로 필요하다

## 구축 로드맵

- [x] 1단계: talos/ + justfile + bootstrap 런북 (이 문서)
- [ ] 2단계: `kubernetes/flux/` — Flux 진입점 + cluster-apps
- [ ] 3단계: `kubernetes/apps/` 플랫폼 — envoy-gateway → gateway → cloudflared 체인, Discord 알림, metrics-server/reloader, grafana-k8s-monitoring(Alloy)
- [ ] 4단계: `kubernetes/apps/sobok/` — 워크로드 6종 + image automation(digest 핀) + GHCR pull secret
- [ ] 5단계: sobok CI 정리 — 승격 PR 잡 삭제, `main-<epoch>-<sha>` 태그
