#!/bin/bash
# Mac mini 무인 서버 초기 설정 — sudo로 최초 1회 실행한다 (idempotent)
# 잠자기 금지·정전 자동 재시작·자동 업데이트 차단·인덱싱/백업 제외
set -euo pipefail

if (( EUID != 0 )); then
  echo "sudo로 실행하세요: sudo bash host/host-prep.sh" >&2
  exit 1
fi

# 전원: 잠자기 전면 금지(HVF 시계 드리프트 방지 겸용) + 정전 복구·프리즈 시 자동 재시작
pmset -a sleep 0 displaysleep 0 disksleep 0 powernap 0 womp 1 tcpkeepalive 1 autorestart 1
systemsetup -setrestartfreeze on >/dev/null

# macOS 자동 설치 차단 — OS 업데이트는 유지보수 윈도우에 수동으로만 한다
# (보안 구성 데이터 XProtect/BSI는 재부팅이 없으므로 자동 유지)
softwareupdate --schedule off >/dev/null
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

# 전용 서버라 Spotlight 인덱싱은 전부 끈다. VM 디렉터리는 Time Machine에서도 제외
mdutil -a -i off >/dev/null 2>&1 || true
mkdir -p /opt/sobok/vm
tmutil addexclusion /opt/sobok/vm 2>/dev/null || true

echo "완료. 확인:"
pmset -g | grep -E 'sleep|womp|autorestart|powernap' | sed 's/^/  /'
echo "  FileVault authrestart 지원: $(fdesetup supportsauthrestart 2>/dev/null || echo 확인불가)"
