# 계정 Secrets Store id. turnstile·vibe·stella 워크스페이스가 terraform_remote_state로 읽어
# cloudflare_secrets_store_secret.store_id에 쓴다(손으로 주입하던 var.secrets_store_id를 대체).
# Remote State Sharing을 이 워크스페이스에서 위 세 워크스페이스로 활성화해야 한다(HCP, 수동).
output "store_id" {
  description = "계정 Secrets Store id. turnstile·vibe·stella가 remote_state로 읽는다."
  value       = cloudflare_secrets_store.sobok.id
}
