# Zone 전체 응답에서 origin 기술 노출 헤더만 제거한다. visitor location/security header transform은
# 애플리케이션 입력·응답 정책을 바꾸므로 범용 baseline에 포함하지 않는다.
resource "cloudflare_managed_transforms" "baseline" {
  zone_id = data.cloudflare_zone.sobok_cc.id

  managed_request_headers = []

  managed_response_headers = [
    {
      id      = "remove_x-powered-by_header"
      enabled = true
    },
  ]
}
