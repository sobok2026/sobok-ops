resource "cloudflare_url_normalization_settings" "default" {
  zone_id = data.cloudflare_zone.sobok_cc.id
  type    = "cloudflare"
  scope   = "incoming"

  lifecycle {
    prevent_destroy = true
  }
}
