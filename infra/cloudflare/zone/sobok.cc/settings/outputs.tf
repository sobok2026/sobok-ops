output "managed_zone_settings" {
  description = "Zone setting IDs owned by this workspace."

  value = sort(concat(
    keys(cloudflare_zone_setting.baseline),
    [cloudflare_zone_setting.hsts.setting_id],
  ))
}
