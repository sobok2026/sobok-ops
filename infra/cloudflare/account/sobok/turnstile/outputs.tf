output "turnstile_sitekey" {
  description = "웹 클라이언트 사이트키(공개값). sobok 레포 apps/web/public.env의 NEXT_PUBLIC_TURNSTILE_SITE_KEY로 커밋한다."
  value       = cloudflare_turnstile_widget.sobok.sitekey
}

# `terraform output -raw turnstile_secret_key`로 꺼내 sops로 봉인한다
output "turnstile_secret_key" {
  description = "siteverify 시크릿. kubernetes/apps/sobok/api/app/secret.sops.yaml의 TURNSTILE_SECRET_KEY에 봉인한다."
  value       = cloudflare_turnstile_widget.sobok.secret
  sensitive   = true
}
