resource "cloudflare_bot_management" "default" {
  zone_id = data.cloudflare_zone.sobok_cc.id

  crawler_protection    = "enabled"
  enable_js             = true
  fight_mode            = true
  is_robots_txt_managed = true

  depends_on = [cloudflare_access_rule.portone_webhook]

  # The Cloudflare provider's Delete operation only removes this resource from Terraform state; it
  # does not disable Bot Fight Mode in the API. Require an explicit fight_mode = false apply first.
  lifecycle {
    prevent_destroy = true
  }
}
