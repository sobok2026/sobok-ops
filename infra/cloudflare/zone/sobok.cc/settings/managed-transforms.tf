# 명시적으로 소유하는 Managed Transforms. 대시보드에서 토글이 바뀌어도 apply가 되돌리도록 켠 것과 끈
# 것을 모두 나열한다(드리프트 방지).
# - remove_visitor_ip_headers=false: 켜지면 CF-Connecting-IP가 제거돼 터널→Envoy의 클라이언트 IP가
#   깨지므로 명시적으로 끈다.
# - add_waf_credential_check_status_header=true: origin에 Exposed-Credential-Check 헤더를 전달해
#   better-auth가 소비한다. Free에선 detection이 걸릴 때만 password_leaked(값 4)를 채운다.
# - add_visitor_location_headers=true: cf-ipcountry 등 지오 헤더를 origin에 전달한다.
# - add_security_headers=false: 번들에 deprecated(X-XSS-Protection, Expect-CT) 헤더가 있고 referrer-policy가
#   attribution을 깰 수 있어 끈다. 보안 응답 헤더는 Worker/앱에서 CSP로 정밀 설정한다.
# 넣지 않는 것: add_client_certificate_headers(mTLS 미사용), add_true_client_ip_headers(Enterprise 전용).
resource "cloudflare_managed_transforms" "baseline" {
  zone_id = data.cloudflare_zone.sobok_cc.id

  managed_request_headers = [
    {
      id      = "add_visitor_location_headers"
      enabled = true
    },
    {
      id      = "add_waf_credential_check_status_header"
      enabled = true
    },
    {
      id      = "remove_visitor_ip_headers"
      enabled = false
    },
  ]

  managed_response_headers = [
    {
      id      = "add_security_headers"
      enabled = false
    },
    {
      id      = "remove_x-powered-by_header"
      enabled = true
    },
  ]
}
