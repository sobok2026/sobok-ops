variable "discord_critical_webhook_url" {
  description = "critical 알림용(및 기본 catch-all) Discord webhook URL."
  type        = string
  nullable    = false
  sensitive   = true
}

variable "discord_warning_webhook_url" {
  description = "warning 알림(severity=warning)용 Discord webhook URL."
  type        = string
  nullable    = false
  sensitive   = true
}
