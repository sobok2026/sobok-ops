# account_id/zone_id는 워크스페이스 변수 대신 zone에서 파생한다 (tunnel·turnstile 모듈과 동일 패턴)
variable "domain" {
  description = "Primary Cloudflare zone name."
  type        = string
  default     = "sobok.cc"
  nullable    = false
}
