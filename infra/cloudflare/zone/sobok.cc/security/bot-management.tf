# Free plan Bot Fight Mode는 Zone 전체에 적용되고 endpoint별 예외를 지원하지 않는다. PortOne
# server-to-server webhook이 먼저 허용된 뒤에만 활성화한다.
# AI crawler 차단 정책은 서비스 공통 bot 방어가 아니라 콘텐츠 정책이므로 여기서 소유하지 않는다.
# managed robots.txt는 애플리케이션의 robots.txt를 authoritative하게 유지하도록 명시적으로 끈다.
resource "cloudflare_bot_management" "default" {
  zone_id = data.cloudflare_zone.sobok_cc.id

  fight_mode            = true
  is_robots_txt_managed = false

  depends_on = [cloudflare_access_rule.portone_webhook]

  # The Cloudflare provider's Delete operation only removes this resource from Terraform state; it
  # does not disable Bot Fight Mode in the API. Require an explicit fight_mode = false apply first.
  lifecycle {
    prevent_destroy = true
  }
}
