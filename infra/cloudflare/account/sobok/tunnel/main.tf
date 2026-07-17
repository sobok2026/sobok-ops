terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  cloud {
    organization = "sobok"

    workspaces {
      project = "cloudflare"
      name    = "account-selfhost-tunnel"
    }
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # tunnel token data source는 5.8.2+ 필요
      version = ">= 5.16.0, < 6.0.0"
    }
  }
}

provider "cloudflare" {}

variable "domain" {
  description = "Primary Cloudflare zone name."
  type        = string
  default     = "sobok.cc"
  nullable    = false
}

# account_id/zone_id는 워크스페이스 변수 대신 zone에서 파생한다 (workers 모듈과 동일 패턴)
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

# k8s Secret(network/tunnel-token) 원본 — `terraform output -raw tunnel_token` 후 sops로 봉인
output "tunnel_token" {
  description = "cloudflared 커넥터 토큰. kubernetes/apps/network/cloudflared/app/secret.sops.yaml에 봉인한다."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.selfhost.token
  sensitive   = true
}

output "tunnel_cname" {
  description = "DNS 컷오버 대상 CNAME 값."
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.selfhost.id}.cfargotunnel.com"
}
