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
