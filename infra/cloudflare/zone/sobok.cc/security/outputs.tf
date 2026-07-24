output "bot_fight_mode_enabled" {
  description = "Whether Bot Fight Mode is enabled."
  value       = cloudflare_bot_management.default.fight_mode
}

output "leaked_credentials_detection_enabled" {
  description = "Whether WAF leaked credential detection is enabled."
  value       = cloudflare_leaked_credential_check.default.enabled
}

output "portone_webhook_allowed_ips" {
  description = "PortOne V2 webhook source IPs allowed before Bot Fight Mode evaluation."
  value       = sort(keys(cloudflare_access_rule.portone_webhook))
}
