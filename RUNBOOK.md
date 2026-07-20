## 부트스트랩 런북

새 Mac(관리 머신)이든 새 VM(DR)이든 순서는 같다. 소요 시간은 VM 생성 포함 30분 내외.

### 0. 도구

```bash
# .mise.toml 버전 핀 그대로 설치
mise install
```

### 1. age 키와 SOPS

```bash
# 키 생성(있으면 스킵) + 공개키 출력
just age-keygen
```

- 출력된 공개키(`age1...`)로 `.sops.yaml`의 `<AGE_PUBLIC_KEY>` 두 곳을 교체한다 (최초 1회)
- 개인키 파일을 오프라인 백업한다 (DR의 뿌리)
- DR 시나리오(키가 이미 있는 경우): 백업한 keys.txt를 위 경로에 복원만 하면 된다

### 2. tailscale 시크릿 (최초 1회)

[Tailscale admin console](https://login.tailscale.com/admin/settings/oauth)에서 OAuth client를 만든다 — scope `auth_keys`, 태그 `tag:sobok`. 태그는 먼저 ACL 정책 파일의 `tagOwners` 블록에 `"tag:sobok": ["autogroup:admin"]`으로 선언해야 한다. OAuth secret은 만료가 없어 authkey 90일 만료 문제를 피한다.

```bash
# 새 파일이 에디터로 열림
cd talos && sops talenv.sops.yaml
```

```yaml
TAILSCALE_AUTHKEY: tskey-client-xxxxx?ephemeral=false&preauthorized=true
```

`ephemeral=false`가 중요하다. 기본값 true면 노드가 오프라인일 때 tailnet에서 자동 삭제된다.

### 3. Mac mini 호스트 구성

Mac mini에서 실행한다 (SSH 접속으로 충분 — GUI 로그인 불필요).

```bash
brew install qemu just socat   # socat은 비상 콘솔(vm-console)용
just host-prep      # 잠자기 금지·정전 자동 재시작·자동 업데이트 차단 (최초 1회)
just host-install   # /opt/sobok/vm 구성 + LaunchDaemon 등록·시작
just vm-fetch-iso "<관리 머신에서 just talos-iso-url로 출력한 URL>"
just vm-restart     # ISO 부팅 → maintenance mode 진입
```

VM 사양(10 코어 / 12 GiB / raw 60 GiB / MAC `f2:50:b0:0c:00:01`)과 네트워크는 전부
[host/vm.env](host/vm.env)에 선언되어 있다. 동작 원리:

- **부팅 = 시작.** `org.sobok.vm`은 root LaunchDaemon이라 FileVault 잠금해제 직후 로그인 없이 시작되고 KeepAlive가 크래시·게스트 재부팅을 재기동한다. 자동 로그인·로그인 항목이 필요 없다
- **서브넷은 QEMU 인자로 고정된다.** `vmnet-shared,start-address=192.168.64.1,end-address=192.168.64.9`라 macOS lease 드리프트가 없고 DHCP 풀(.2~.9)이 정적 IP `.10`과 충돌할 수 없다 — bootptab 예약 불필요
- **ISO는 빈 디스크일 때만 붙는다.** run-vm.sh가 디스크의 GPT 유무로 판단하므로 설치 후 `boot.iso`가 남아 있어도 무해하다 (정리하려면 `sudo rm /opt/sobok/vm/boot.iso`)
- **종료는 ACPI로 우아하게.** `just vm-stop`(launchctl bootout)·호스트 종료 시 SIGTERM → 모니터 소켓 `system_powerdown` → Talos가 정상 종료된다
- 시리얼 콘솔은 `/opt/sobok/vm/log/serial.log`에 항상 기록되고(maintenance IP 확인) 비상 시 `just vm-console`로 접속한다 (종료 Ctrl+])
- 부팅 ISO 스키마틱: tailscale 확장 + `console=ttyAMA0` + arm64 — `metal-arm64.iso`인지 확인

### 4. Talos 설치

```bash
just talos-secret            # 머신 시크릿 생성 + SOPS 봉인 (최초 1회, DR 시엔 기존 파일 재사용)
just talos-genconfig         # clusterconfig/ 생성 (커밋 금지 대상)
just vm-ip                   # VM 부팅 후 maintenance mode DHCP IP 확인 (또는 시리얼 콘솔)
# 이 시점에 디스크/NIC 실측 확인 권장:
#   talosctl -n <maintenance-ip> get disks --insecure   → /dev/vda 확인
#   talosctl -n <maintenance-ip> get links --insecure   → virtio_net 확인
just talos-apply-first 192.168.64.2<maintenance-ip>   # 설치 시작 → 재부팅 후 정적 IP 192.168.64.10
just talos-bootstrap         # etcd 부트스트랩 (성공까지 자동 재시도)
just talos-kubeconfig        # ~/.kube/config 병합
just talos-health
```

노드가 tailnet에 조인하면 talconfig.yaml의 certSANs 주석 두 곳(`sobok-1.<tailnet>.ts.net` — 노드 `certSANs`와 `additionalApiServerCertSans`)을 해제하고 `just talos-genconfig && just talos-apply`로 재적용한다. 이후 어디서든 tailnet 경유 talosctl/kubectl이 된다.

DR 재설치 시에는 admin console에서 기존 `sobok-1` 머신을 먼저 삭제한다. 남아 있으면 새 노드가 `sobok-1-1`로 밀려나 certSANs의 MagicDNS 이름과 어긋난다.

### 5. 앱 시크릿 봉인 (최초 1회)

앱 10개가 SOPS 시크릿을 참조한다(플랫폼 3 + ghcr-pull + 워크로드 6). 각 위치의 `secret.sops.yaml.example`을 참고해 실제 파일을 만든다 — `sops <경로>`가 에디터를 열고 저장 시 자동 암호화한다.

```bash
# Discord 웹훅 (채널 설정 → 연동 → 웹훅 생성)
sops kubernetes/apps/flux-system/notifications/app/secret.sops.yaml
# 터널 토큰 (infra/.../selfhost-tunnel에서 terraform apply 후 output -raw tunnel_token)
sops kubernetes/apps/network/cloudflared/app/secret.sops.yaml
# Grafana Cloud 자격증명 (콘솔 스택 상세의 인스턴스 ID + Access Policy 토큰)
sops kubernetes/apps/observability/grafana-k8s-monitoring/app/secret.sops.yaml
# GHCR pull 자격증명 — 생성 명령은 example 파일 상단 주석 참고 (read:packages PAT)
# → kubernetes/apps/sobok/ghcr-pull/app/secret.sops.yaml
# 워크로드 런타임 시크릿 6개 (Aiven·CockroachDB·better-auth·PortOne·VAPID 등)
sops kubernetes/apps/sobok/web/app/secret.sops.yaml
sops kubernetes/apps/sobok/api/app/secret.sops.yaml
sops kubernetes/apps/sobok/chat/app/secret.sops.yaml
sops kubernetes/apps/sobok/chat-worker/app/secret.sops.yaml
sops kubernetes/apps/sobok/chat-push/app/secret.sops.yaml
sops kubernetes/apps/sobok/billing-worker/app/secret.sops.yaml
```

평문 플레이스홀더도 함께 교체한다: 각 앱 `app/kustomization.yaml`의 `KAFKA_BROKERS`·`VAPID_PUBLIC_KEY`·`OTEL_EXPORTER_OTLP_ENDPOINT`(`<...>` 표기).

grafana-k8s-monitoring의 helmrelease.yaml에 있는 push URL 두 곳(`<GRAFANA_CLOUD_*_PUSH_URL>`)도 콘솔 값으로 교체한다. URL은 비밀이 아니라 평문 values로 둔다.

**만든 암호문 10개 전부와 URL 교체분을 커밋·푸시한 뒤 다음 단계로 간다.** Flux는 GitHub에서만 pull하므로 로컬 파일은 클러스터에 반영되지 않는다 — 커밋 없이 flux-up을 돌리면 시크릿을 참조하는 ks 10개가 빌드 에러로 실패하고, 알림 앱 자체가 그 안에 포함되어 Discord로는 아무 경보도 오지 않는다.

**선행 조건: 5단계(CI 태그 스킴)가 sobok 레포 main에 먼저 머지되어 `main-<epoch>-<sha>` 태그가 각 이미지에 최소 1개 존재해야 한다.** 매칭 태그가 0개면 ImagePolicy 6개가 Ready False가 되어 워크로드 Kustomization 전부가 수렴 실패로 표시되고 Discord 에러가 반복된다 (워크로드 자체는 `:main` 태그로 뜨긴 한다).

### 6. Flux 설치

```bash
just seal-age-key            # age 키 → bootstrap/sops-age.sops.yaml 암호문 (최초 1회)
export GITHUB_TOKEN="$(gh auth token)"   # 또는 생략 — flux-up이 프롬프트로 받는다 (인라인 할당은 셸 히스토리에 남으니 금지)
just flux-up
```

`flux bootstrap`은 멱등이라 재실행해도 안전하다. 수렴 확인은 `flux get kustomizations -A` — 전부 Ready True면 끝. 이후는 전부 GitOps — `kubernetes/`에 커밋하면 Flux가 수렴시킨다.

트래픽 컷오버는 별도 결정 사항이다: 현재 `sobok.cc` apex는 `stella` 워커(`infra/cloudflare/account/sobok/workers/stella`)가 서빙 중이고(AdSense 심사용으로 실제 앱을 apex에 임시 바인딩), 터널 검증 후 apex CNAME을 `terraform output tunnel_cname` 값으로 교체할 때 selfhost-tunnel의 주석 처리된 `cloudflare_dns_record`를 활성화하고 stella의 apex 바인딩을 제거한다.
