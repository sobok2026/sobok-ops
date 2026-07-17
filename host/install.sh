#!/bin/bash
# VM 데몬 설치·갱신 — Mac mini에서 sudo로 실행한다 (idempotent, 실행 시 VM 재시작)
# 선행 조건: brew install qemu (socat은 vm-console용 선택)
set -euo pipefail

if (( EUID != 0 )); then
  echo "sudo로 실행하세요: sudo bash host/install.sh" >&2
  exit 1
fi

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
VM_DIR=/opt/sobok/vm
QEMU_BIN=/opt/homebrew/bin/qemu-system-aarch64
FIRMWARE_DIR=/opt/homebrew/share/qemu

[[ $(uname -m) == arm64 ]] || { echo "Apple Silicon 전용입니다" >&2; exit 1; }
[[ -x $QEMU_BIN ]] || { echo "QEMU가 없습니다: brew install qemu" >&2; exit 1; }
[[ -f $FIRMWARE_DIR/edk2-aarch64-code.fd && -f $FIRMWARE_DIR/edk2-arm-vars.fd ]] \
  || { echo "edk2 펌웨어가 없습니다: $FIRMWARE_DIR" >&2; exit 1; }

mkdir -p "$VM_DIR/bin" "$VM_DIR/log"

install -m 644 "$SRC_DIR/vm.env" "$VM_DIR/vm.env"
install -m 755 "$SRC_DIR/run-vm.sh" "$SRC_DIR/watchdog.sh" "$VM_DIR/bin/"
source "$VM_DIR/vm.env"

# 시스템 디스크 — APFS sparse라 실사용량만 차지한다. 있으면 보존 (갈아엎기는 명시적 rm 후 재실행)
if [[ ! -f $VM_DIR/disk.raw ]]; then
  /opt/homebrew/bin/qemu-img create -f raw "$VM_DIR/disk.raw" "${VM_DISK_GIB}G"
fi

# UEFI 변수 저장소 — 부트 엔트리가 여기 남는다. 있으면 보존
[[ -f $VM_DIR/efi-vars.fd ]] || cp "$FIRMWARE_DIR/edk2-arm-vars.fd" "$VM_DIR/efi-vars.fd"

install -m 644 "$SRC_DIR/org.sobok.vm.plist" "$SRC_DIR/org.sobok.vm-watchdog.plist" /Library/LaunchDaemons/

# 데몬 재등록 — bootout이 실행 중인 VM을 ACPI로 정상 종료시킨다
launchctl bootout system/org.sobok.vm 2>/dev/null || true
until ! pgrep -qf "qemu-system-aarch64 -name $VM_NAME"; do sleep 1; done
launchctl bootstrap system /Library/LaunchDaemons/org.sobok.vm.plist

launchctl bootout system/org.sobok.vm-watchdog 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/org.sobok.vm-watchdog.plist

echo "설치 완료 — VM 데몬이 시작됐습니다"
echo "- 상태: just vm-status / 시리얼 로그: $VM_DIR/log/serial.log"
if [[ ! -s $VM_DIR/discord-webhook ]]; then
  echo "- 워치독 Discord 알림을 켜려면 웹훅 URL을 저장하세요 (붙여넣기 후 Ctrl+D — 히스토리에 안 남는다):"
  echo "    sudo sh -c 'umask 077; cat > $VM_DIR/discord-webhook'"
fi
