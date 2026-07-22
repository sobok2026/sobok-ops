# PortOne V2 webhook 송신 IP. Bot Fight Mode는 WAF Skip으로 우회할 수 없으므로, Cloudflare의
# 선행 평가 단계인 Zone IP Access Rule Allow를 사용한다. PortOne은 IP 변경 전에 등록 연락처로
# 안내한다: https://developers.portone.io/opi/ko/integration/webhook/readme-v2?v=v2
locals {
  portone_webhook_ips = toset([
    "52.78.5.241",
  ])
}

resource "cloudflare_access_rule" "portone_webhook" {
  for_each = local.portone_webhook_ips

  zone_id = data.cloudflare_zone.sobok_cc.id
  mode    = "whitelist"

  configuration = {
    target = "ip"
    value  = each.value
  }

  notes = "PortOne V2 webhook ${each.value} - bypass Bot Fight Mode"
}
