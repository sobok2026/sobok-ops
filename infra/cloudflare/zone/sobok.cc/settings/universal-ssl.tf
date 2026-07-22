# Free plan의 자동 발급·갱신 edge certificate를 명시적으로 유지한다.
resource "cloudflare_universal_ssl_setting" "default" {
  zone_id = data.cloudflare_zone.sobok_cc.id
  enabled = true
}
