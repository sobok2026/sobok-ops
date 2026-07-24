resource "cloudflare_leaked_credential_check" "default" {
  zone_id = data.cloudflare_zone.sobok_cc.id
  enabled = true

  lifecycle {
    prevent_destroy = true
  }
}
