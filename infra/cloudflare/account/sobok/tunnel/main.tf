data "cloudflare_zone" "sobok_cc" {
  filter = {
    name = var.domain
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "selfhost" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.selfhost.id
}

locals {
  tunnel_name = "sobok-selfhost"
  # k8s network 네임스페이스의 Gateway 프록시 Service (kubernetes/apps/network/gateway/app/envoyproxy.yaml의 고정 이름)
  origin_service = "http://envoy-sobok.network.svc.cluster.local:80"
}

# remotely-managed 터널 — 커넥터(cloudflared Deployment)는 k8s가, ingress 규칙은 여기가 소유한다
resource "cloudflare_zero_trust_tunnel_cloudflared" "selfhost" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  name       = local.tunnel_name
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "selfhost" {
  account_id = data.cloudflare_zone.sobok_cc.account.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.selfhost.id

  config = {
    ingress = [
      # 라우팅은 apex 단일 호스트 + Envoy HTTPRoute의 경로 매칭 (/api, /ws, /*)
      {
        hostname = var.domain
        service  = local.origin_service
      },
      # ingress는 반드시 hostname 없는 catch-all로 끝나야 한다
      {
        service = "http_status:404"
      }
    ]
  }
}

# 컷오버 시점에 활성화 — 현재 apex는 workers(account/sobok/workers/apex)가 서빙 중이라
# 전환 순서(터널 검증 → 레코드 교체 → 워커 라우트 정리)는 사람이 결정한다
# resource "cloudflare_dns_record" "apex" {
#   zone_id = data.cloudflare_zone.sobok_cc.id
#   name    = "@"
#   content = "${cloudflare_zero_trust_tunnel_cloudflared.selfhost.id}.cfargotunnel.com"
#   type    = "CNAME"
#   ttl     = 1
#   proxied = true
# }
