#!/bin/bash
# 호스트 워치독 — launchd(org.sobok.vm-watchdog)가 5분마다 root로 실행한다
# QEMU 프로세스·Talos API·K8s API·디스크·메모리 압력을 점검하고 상태가 바뀔 때 Discord로 알린다
# 웹훅 파일(/opt/sobok/vm/discord-webhook)이 없으면 로그만 남긴다
set -uo pipefail

VM_DIR=${VM_DIR:-/opt/sobok/vm}
source "$VM_DIR/vm.env"

WEBHOOK_FILE="$VM_DIR/discord-webhook"
STATE_FILE="$VM_DIR/log/watchdog.state"
REALERT_SECONDS=$((6 * 60 * 60))

problems=()
pgrep -qf "qemu-system-aarch64 -name $VM_NAME" || problems+=("QEMU 프로세스 없음")
nc -z -G 3 "$NODE_IP" 50000 >/dev/null 2>&1 || problems+=("Talos API($NODE_IP:50000) 응답 없음")
nc -z -G 3 "$NODE_IP" 6443 >/dev/null 2>&1 || problems+=("K8s API($NODE_IP:6443) 응답 없음")

disk_pct=$(df -P "$VM_DIR" | awk 'NR==2 { gsub("%", "", $5); print $5 }')
(( disk_pct >= 90 )) && problems+=("호스트 디스크 ${disk_pct}% 사용")

pressure=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 1)
(( pressure >= 4 )) && problems+=("호스트 메모리 압력 critical")

now=$(date +%s)
if (( ${#problems[@]} > 0 )); then
  state=FAIL
  joined=$(printf '%s; ' "${problems[@]}")
  message="🚨 sobok host: ${joined%; }"
else
  state=OK
  message="✅ sobok host: 정상 복구"
fi

read -r prev_state prev_alert_at < <(cat "$STATE_FILE" 2>/dev/null || echo "OK 0")

notify=false
if [[ $state != "$prev_state" ]]; then
  # OK→FAIL은 즉시, FAIL→OK는 복구 알림
  [[ $state == FAIL || $prev_state == FAIL ]] && notify=true
elif [[ $state == FAIL ]] && (( now - prev_alert_at >= REALERT_SECONDS )); then
  notify=true
fi

if $notify; then
  echo "$(date '+%F %T') $message"
  if [[ -s $WEBHOOK_FILE ]]; then
    curl -m 10 -sS -H 'Content-Type: application/json' \
      -d "{\"content\": \"$message\"}" "$(cat "$WEBHOOK_FILE")" >/dev/null \
      || echo "$(date '+%F %T') Discord 전송 실패"
  fi
  echo "$state $now" > "$STATE_FILE"
fi
