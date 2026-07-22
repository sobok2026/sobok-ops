output "bot_fight_mode_enabled" {
  description = "Whether Bot Fight Mode is enabled."
  value       = cloudflare_bot_management.default.fight_mode
}

output "portone_webhook_allowed_ips" {
  description = "PortOne V2 webhook source IPs allowed before Bot Fight Mode evaluation."
  value       = sort(keys(cloudflare_access_rule.portone_webhook))
}
