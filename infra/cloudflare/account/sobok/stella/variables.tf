# account_id/zone_id는 워크스페이스 변수 대신 zone에서 파생한다 (vibe·tunnel·turnstile·workers 모듈과 동일 패턴).
variable "domain" {
  description = "Primary Cloudflare zone name."
  type        = string
  default     = "sobok.cc"
  nullable    = false
}

variable "stella_ip_hash_salt" {
  description = "익명 댓글 IP 해시용 정적 HMAC salt(회전하지 않음). 강한 랜덤 문자열."
  type        = string
  sensitive   = true
}

variable "stella_discord_webhook" {
  description = "댓글 모더레이션/ops 알림용 Discord 웹훅 URL. 빈 문자열이면 알림 비활성."
  type        = string
  sensitive   = true
  default     = ""
}
