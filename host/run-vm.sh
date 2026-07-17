#!/bin/bash
# sobok-1 QEMU 실행 래퍼 — launchd(org.sobok.vm)가 root로 실행한다
#
# 설계 (Talos 공식 QEMU 프로비저너의 darwin 인자를 그대로 따른다):
# - -no-reboot: 게스트 재부팅이 QEMU 종료가 되고 launchd KeepAlive가 재기동한다.
#   Talos 업그레이드의 A/B 재부팅이 매번 새 QEMU 프로세스로 이어져 인자 변경도 함께 반영된다
# - ISO는 디스크에 GPT가 없을 때만 붙인다 — 설치가 끝나면 파일이 남아 있어도 무시된다
# - SIGTERM(launchctl bootout·호스트 종료)을 받으면 모니터 소켓으로 ACPI 종료를 보내고
#   게스트가 스스로 내려갈 때까지 기다린다. Talos가 ACPI 전원 버튼을 처리한다
set -euo pipefail

VM_DIR=${VM_DIR:-/opt/sobok/vm}
source "$VM_DIR/vm.env"

QEMU_BIN=${QEMU_BIN:-/opt/homebrew/bin/qemu-system-aarch64}
FIRMWARE_DIR=${FIRMWARE_DIR:-/opt/homebrew/share/qemu}
LOG_DIR="$VM_DIR/log"
GRACE_SECONDS=90

# 시리얼 로그 자체 로테이션 — QEMU 시작 전이라 파일을 잡고 있는 프로세스가 없다
if [[ -f "$LOG_DIR/serial.log" ]] && (( $(stat -f %z "$LOG_DIR/serial.log") > 50 * 1024 * 1024 )); then
  mv "$LOG_DIR/serial.log" "$LOG_DIR/serial.log.old"
fi

args=(
  -name "$VM_NAME"
  -machine virt,gic-version=max,accel=hvf
  -cpu max
  -smp "cpus=$VM_CPUS"
  -m "$VM_MEMORY_MIB"
  -display none
  -no-reboot
  -serial chardev:serial0
  -chardev "socket,id=serial0,path=$VM_DIR/console.sock,server=on,wait=off,logfile=$LOG_DIR/serial.log,logappend=on"
  -monitor "unix:$VM_DIR/monitor.sock,server,nowait"
  -smbios "type=1,uuid=$VM_UUID"
  -drive "file=$FIRMWARE_DIR/edk2-aarch64-code.fd,format=raw,if=pflash,readonly=on"
  -drive "file=$VM_DIR/efi-vars.fd,format=raw,if=pflash"
  -drive "id=system,format=raw,if=none,file=$VM_DIR/disk.raw,cache=none,discard=unmap,detect-zeroes=unmap"
  -device virtio-blk-pci,drive=system
  -device virtio-rng-pci
  -device virtio-balloon,deflate-on-oom=on
  -device i6300esb,id=watchdog0
  -action watchdog=reset
  -netdev "vmnet-shared,id=net0,start-address=$NET_START,end-address=$NET_END,subnet-mask=$NET_MASK"
  -device "virtio-net-pci,netdev=net0,mac=$VM_MAC"
)

# 설치 전(디스크 LBA1에 GPT 시그니처 없음)에만 부팅 ISO를 붙인다
# 이때 UEFI 변수도 초기화한다 — ISO 없는 선행 부팅이 남긴 BootOrder는 CD 항목이 없고
# EFI Shell에서 멈추므로 펌웨어가 CD를 재열거하도록 백지에서 시작해야 한다
if [[ -f "$VM_DIR/boot.iso" ]] \
  && ! dd if="$VM_DIR/disk.raw" bs=512 skip=1 count=1 2>/dev/null | LC_ALL=C grep -aq 'EFI PART'; then
  cp "$FIRMWARE_DIR/edk2-arm-vars.fd" "$VM_DIR/efi-vars.fd"
  args+=(-drive "id=cdrom1,file=$VM_DIR/boot.iso,media=cdrom")
fi

"$QEMU_BIN" "${args[@]}" &
qemu_pid=$!

on_term() {
  printf 'system_powerdown\n' | nc -U -w 2 "$VM_DIR/monitor.sock" >/dev/null 2>&1 || true
  local waited=0
  while kill -0 "$qemu_pid" 2>/dev/null; do
    if (( waited >= GRACE_SECONDS )); then
      kill -KILL "$qemu_pid" 2>/dev/null || true
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
}
trap on_term TERM INT

# 시그널로 wait가 중단되면 재수확해 실제 종료 코드를 얻는다
rc=0
while kill -0 "$qemu_pid" 2>/dev/null; do
  wait "$qemu_pid" && rc=0 || rc=$?
done
exit "$rc"
