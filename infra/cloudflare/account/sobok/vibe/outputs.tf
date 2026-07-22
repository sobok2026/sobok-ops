# 딥타입 Hyperdrive config id 두 개. `terraform output`으로 꺼내 sobok 레포 apps/vibe/wrangler.jsonc의
# hyperdrive 바인딩(HYPERDRIVE_FRESH / HYPERDRIVE_CACHED) id로 커밋한다(KV namespace id와 동일 패턴).
output "deeptype_hyperdrive_fresh_id" {
  description = "wrangler.jsonc HYPERDRIVE_FRESH 바인딩 id."
  value       = cloudflare_hyperdrive_config.deeptype_fresh.id
}

output "deeptype_hyperdrive_cached_id" {
  description = "wrangler.jsonc HYPERDRIVE_CACHED 바인딩 id."
  value       = cloudflare_hyperdrive_config.deeptype_cached.id
}
