# account_id는 워크스페이스 변수 대신 zone에서 파생한다
variable "domain" {
  description = "Primary Cloudflare zone name."
  type        = string
  default     = "sobok.cc"
  nullable    = false
}

variable "store_name" {
  description = "계정 Secrets Store 이름. `wrangler secrets-store store list`의 기존 스토어 이름과 정확히 일치시킨다."
  type        = string
  nullable    = false
}
