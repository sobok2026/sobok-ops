# Consumed by the account-vibe workspace via the tfe_outputs data source (remote state sharing must be
# enabled FROM this workspace TO account-vibe). These feed the two Cloudflare Hyperdrive origins and stay
# LINKED — no manual copy. The DB PASSWORD is intentionally NOT output: it is write-only and never in this
# state under the import path, so it is set directly as a sensitive HCP variable on account-vibe.
#
# Hyperdrive MUST target the SESSION pooler (port 5432, user postgres.<ref>), never the 6543 transaction
# pooler (double-pooling + prepared-statement conflicts; Hyperdrive is itself the pooling layer).
output "deeptype_pg_host" {
  description = "세션 풀러 호스트(Hyperdrive origin host)."
  value       = var.pooler_host
}

output "deeptype_pg_port" {
  description = "세션 풀러 포트(5432, 세션 모드)."
  value       = 5432
}

output "deeptype_pg_database" {
  description = "데이터베이스 이름(Supabase 기본값 postgres)."
  value       = "postgres"
}

output "deeptype_pg_user" {
  description = "세션 풀러 사용자(postgres.<project-ref> 테넌트 라우팅 형식)."
  value       = "postgres.${supabase_project.deeptype.id}"
  sensitive   = true
}
