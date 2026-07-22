# account_id/zone_id는 워크스페이스 변수 대신 zone에서 파생한다 (tunnel·turnstile·workers 모듈과 동일 패턴)
variable "domain" {
  description = "Primary Cloudflare zone name."
  type        = string
  default     = "sobok.cc"
  nullable    = false
}

# ── 딥타입 DB 비밀번호 ──────────────────────────────────────────────────────────────────────────────
variable "deeptype_pg_password" {
  description = "Supabase DB 비밀번호(대시보드 값, write-only). Hyperdrive origin password."
  type        = string
  sensitive   = true
}

# ── Cloudflare Secrets Store ────────────────────────────────────────────────────────────────────────
variable "secrets_store_id" {
  description = "계정 Secrets Store id(계정당 1개). `wrangler secrets-store store list` 또는 대시보드에서 확인."
  type        = string
}

variable "deeptype_portone_api_secret" {
  description = "딥타입 전용 PortOne 스토어 API secret."
  type        = string
  sensitive   = true
}

variable "deeptype_portone_webhook_secret" {
  description = "딥타입 PortOne 웹훅 secret(Standard Webhooks 서명)."
  type        = string
  sensitive   = true
}

variable "deeptype_anthropic_api_key" {
  description = "리포트 생성용 Anthropic API 키."
  type        = string
  sensitive   = true
}

variable "sobok_turnstile_secret" {
  description = "공유 sobok Turnstile 위젯 secret(account-turnstile output turnstile_secret_key)."
  type        = string
  sensitive   = true
}

variable "deeptype_discord_webhook" {
  description = "money/ops 알림용 Discord 웹훅 URL. 빈 문자열이면 알림 비활성."
  type        = string
  sensitive   = true
  default     = ""
}
