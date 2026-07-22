locals {
  # 모든 scalar cloudflare_zone_setting은 이 map이 단독 소유한다. Dashboard 메뉴나 값 자료형에 따라
  # 다른 state로 나누지 않는다.
  scalar_zone_settings = {
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    browser_check            = "on"
    # Cloudflare's default and recommended 15-45 minute range midpoint.
    challenge_ttl            = 1800
    early_hints              = "on"
    ech                      = "on"
    email_obfuscation        = "on"
    http3                    = "on"
    min_tls_version          = "1.2"
    opportunistic_encryption = "on"
    opportunistic_onion      = "on"
    replace_insecure_js      = "on"
    ssl                      = "strict"
    tls_1_3                  = "zrt"
    websockets               = "on"
  }
}

resource "cloudflare_zone_setting" "baseline" {
  for_each = local.scalar_zone_settings

  zone_id    = data.cloudflare_zone.sobok_cc.id
  setting_id = each.key
  value      = each.value

  depends_on = [cloudflare_universal_ssl_setting.default]

  # Provider Delete는 API를 변경하지 않고 Terraform state만 제거한다.
  lifecycle {
    prevent_destroy = true
  }
}

# Cloudflare edge가 origin 종류와 관계없이 동일한 HSTS 정책을 보장한다. Cloudflare의 Zone HSTS
# max-age 상한은 12개월이며, preload 목록의 최소 요건도 12개월이다. `preload = true`는 응답
# directive만 추가하고 브라우저 preload 목록 제출을 대신하지 않는다.
resource "cloudflare_zone_setting" "hsts" {
  zone_id    = data.cloudflare_zone.sobok_cc.id
  setting_id = "security_header"

  value = {
    strict_transport_security = {
      enabled            = true
      include_subdomains = true
      max_age            = 31536000
      nosniff            = true
      preload            = true
    }
  }

  depends_on = [cloudflare_zone_setting.baseline]

  # HSTS를 비활성화하지 않은 채 state에서만 제거하는 것을 막는다.
  lifecycle {
    prevent_destroy = true
  }
}
