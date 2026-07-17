# sobok-ops 런북 — DR 절차를 실행 가능한 코드로 고정한다
# 도구는 .mise.toml 버전 핀을 따른다 (mise install)

set shell := ["bash", "-euo", "pipefail", "-c"]

github_owner := "sobok2026"
github_repo := "sobok-ops"
node_ip := "192.168.64.10"
vm_name := "sobok-1"
# locally administered MAC 주소 — host/vm.env의 VM_MAC과 일치해야 한다
vm_mac := "f2:50:b0:0c:00:01"
age_key_file := env("SOPS_AGE_KEY_FILE", env("HOME") + "/Library/Application Support/sops/age/keys.txt")

[private]
default:
    @just --list

# age 키 생성 (있으면 건너뜀) + 공개키 출력. 개인키는 즉시 오프라인 백업할 것
age-keygen:
    #!/usr/bin/env bash
    set -euo pipefail
    key_file="{{ age_key_file }}"
    if [ -f "$key_file" ]; then
      echo "이미 존재: $key_file"
    else
      mkdir -p "$(dirname "$key_file")"
      age-keygen -o "$key_file"
    fi
    echo "공개키: $(age-keygen -y "$key_file")"
    echo "→ .sops.yaml의 <AGE_PUBLIC_KEY>를 위 공개키로 교체하고 개인키 파일을 오프라인 백업하세요"

# age 개인키를 sops-age Secret 암호문으로 봉인해 레포에 커밋 가능하게 만든다
seal-age-key:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p bootstrap
    trap 'rm -f bootstrap/sops-age.sops.yaml.tmp' EXIT
    kubectl create secret generic sops-age \
      --namespace=flux-system \
      --from-file=age.agekey="{{ age_key_file }}" \
      --dry-run=client --output=yaml \
      | sops --filename-override bootstrap/sops-age.sops.yaml --encrypt /dev/stdin \
      > bootstrap/sops-age.sops.yaml.tmp
    mv bootstrap/sops-age.sops.yaml.tmp bootstrap/sops-age.sops.yaml
    echo "생성됨: bootstrap/sops-age.sops.yaml"

# Talos 머신 시크릿 생성 + SOPS 봉인 (있으면 건너뜀 — 갈아치우면 클러스터 접근을 잃는다)
[working-directory: 'talos']
talos-secret:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -s talsecret.sops.yaml ]; then
      echo "이미 존재: talos/talsecret.sops.yaml (의도적 재생성이면 파일을 먼저 지우세요)"
    else
      rm -f talsecret.sops.yaml
      trap 'rm -f talsecret.sops.yaml.tmp' EXIT
      talhelper gensecret | sops --filename-override talsecret.sops.yaml --encrypt /dev/stdin > talsecret.sops.yaml.tmp
      mv talsecret.sops.yaml.tmp talsecret.sops.yaml
      echo "생성됨: talos/talsecret.sops.yaml"
    fi

# 머신 컨피그 생성 (clusterconfig/ — gitignore 대상, 평문 비밀 포함)
[working-directory: 'talos']
talos-genconfig:
    talhelper genconfig

# 부팅 ISO URL 출력 (스키마틱·arm64 반영). Mac mini에서 just vm-fetch-iso에 넘긴다
[working-directory: 'talos']
talos-iso-url:
    talhelper genurl image

# VM의 maintenance mode DHCP IP 확인 (호스트 DHCP lease에서 MAC 검색)
vm-ip:
    #!/usr/bin/env bash
    set -euo pipefail
    mac="{{ vm_mac }}"
    # bootpd는 lease 기록 시 옥텟 앞자리 0을 생략한다 → 두 표기 모두 검색
    stripped=$(echo "$mac" | awk -F: '{ for (i = 1; i <= NF; i++) { sub(/^0/, "", $i); printf "%s%s", $i, (i < NF ? ":" : "") } }')
    grep -B2 -A3 -i -e "$mac" -e "$stripped" /var/db/dhcpd_leases 2>/dev/null \
      || echo "MAC $mac lease 없음 — VM 부팅을 확인하거나 시리얼 로그(/opt/sobok/vm/log/serial.log)로 확인하세요"

# ── 아래 host-*·vm-* 레시피는 Mac mini(호스트)에서 실행한다 ──

# 무인 서버 초기 설정: 잠자기 금지·정전 자동 재시작·자동 업데이트 차단 (최초 1회)
host-prep:
    sudo bash host/host-prep.sh

# VM 데몬 설치·갱신: /opt/sobok/vm 구성 + LaunchDaemon 등록 (실행 시 VM 재시작)
host-install:
    sudo bash host/install.sh

# FileVault 잠금해제를 1회 생략하는 호스트 재시작 — VM을 먼저 정상 종료한다
host-restart:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo launchctl bootout system/org.sobok.vm 2>/dev/null || true
    until ! pgrep -qf 'qemu-system-aarch64 -name {{ vm_name }}'; do sleep 1; done
    sudo fdesetup authrestart

# 부팅 ISO 배치 (url = 관리 머신에서 just talos-iso-url로 출력한 값)
vm-fetch-iso url:
    sudo curl -fSLo /opt/sobok/vm/boot.iso "{{ url }}"

# VM 시작 (부팅 시엔 자동 시작되므로 vm-stop 후 재개용)
vm-start:
    sudo launchctl bootstrap system /Library/LaunchDaemons/org.sobok.vm.plist

# VM 정지 (ACPI 정상 종료 후 다음 호스트 부팅 전까지 유지)
vm-stop:
    sudo launchctl bootout system/org.sobok.vm

# VM 정상 종료 후 재시작
vm-restart:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo launchctl bootout system/org.sobok.vm 2>/dev/null || true
    until ! pgrep -qf 'qemu-system-aarch64 -name {{ vm_name }}'; do sleep 1; done
    sudo launchctl bootstrap system /Library/LaunchDaemons/org.sobok.vm.plist

# VM 데몬·프로세스 상태
vm-status:
    #!/usr/bin/env bash
    sudo launchctl print system/org.sobok.vm 2>/dev/null | grep -E '(state|pid) = ' || echo "org.sobok.vm 미등록"
    pgrep -fl 'qemu-system-aarch64 -name {{ vm_name }}' >/dev/null && echo "QEMU 실행 중" || echo "QEMU 프로세스 없음"

# 비상 시리얼 콘솔 접속 (종료: Ctrl+])
vm-console:
    sudo socat -,raw,echo=0,escape=0x1d unix-connect:/opt/sobok/vm/console.sock

# 첫 설치: maintenance mode 노드에 무인증 적용 (ip = vm-ip로 확인한 DHCP IP)
[working-directory: 'talos']
talos-apply-first ip:
    talosctl apply-config --insecure --nodes {{ ip }} --file clusterconfig/sobok-prod-sobok-1.yaml

# 설치 후 컨피그 재적용 (talosconfig 인증, 정적 IP 대상)
[working-directory: 'talos']
talos-apply:
    talhelper gencommand apply | bash

# etcd 부트스트랩 — 설치 재부팅 직후엔 실패하므로 성공까지 10초 간격 재시도
[working-directory: 'talos']
talos-bootstrap:
    until talhelper gencommand bootstrap | bash; do sleep 10; done

# kubeconfig 회수 (~/.kube/config에 병합)
[working-directory: 'talos']
talos-kubeconfig:
    until talhelper gencommand kubeconfig --extra-flags "--force" | bash; do sleep 10; done

# 클러스터 헬스 체크
[working-directory: 'talos']
talos-health:
    talosctl --talosconfig clusterconfig/talosconfig --nodes {{ node_ip }} --endpoints {{ node_ip }} health

# Talos OS 업그레이드 (talenv.yaml의 talosVersion을 올린 뒤 실행 — 스키마틱 ID가 유지된다)
[working-directory: 'talos']
talos-upgrade:
    talhelper gencommand upgrade | bash

# Kubernetes 업그레이드 (talenv.yaml의 kubernetesVersion을 올린 뒤 실행)
[working-directory: 'talos']
talos-upgrade-k8s:
    talhelper gencommand upgrade-k8s | bash

# Flux 설치: ns 선생성 → sops-age Secret 주입 → flux bootstrap (GITHUB_TOKEN 필요)
flux-up:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "${GITHUB_TOKEN:-}" ]; then
      # 인라인 env 할당은 셸 히스토리에 PAT를 남기므로 프롬프트로 받는다
      read -rs -p "GitHub PAT (repo 스코프): " GITHUB_TOKEN && echo
      export GITHUB_TOKEN
    fi
    kubectl create namespace flux-system --dry-run=client --output=yaml | kubectl apply --server-side --filename -
    sops exec-file bootstrap/sops-age.sops.yaml 'kubectl --namespace flux-system apply --server-side --filename {}'
    flux bootstrap github \
      --owner={{ github_owner }} \
      --repository={{ github_repo }} \
      --branch=main \
      --path=kubernetes/flux \
      --personal \
      --components-extra=image-reflector-controller,image-automation-controller \
      --read-write-key
