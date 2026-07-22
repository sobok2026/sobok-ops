# Free plan의 자동 발급·갱신 edge certificate를 명시적으로 유지한다.
resource "cloudflare_universal_ssl_setting" "default" {
  zone_id = data.cloudflare_zone.sobok_cc.id
  enabled = true

  # Provider Delete는 API를 변경하지 않고 Terraform state만 제거한다.
  lifecycle {
    prevent_destroy = true
  }
}
