# stella Hyperdrive config id. `terraform output`으로 꺼내 sobok 레포 apps/stella/wrangler.jsonc의
# hyperdrive 바인딩(HYPERDRIVE) id로 커밋한다(account-vibe와 동일 패턴).
output "stella_hyperdrive_id" {
  description = "wrangler.jsonc HYPERDRIVE 바인딩 id."
  value       = cloudflare_hyperdrive_config.stella.id
}
