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
  description = "deeptype 런타임 역할 세션 풀러 사용자(deeptype_app.<project-ref>)."
  value       = "deeptype_app.${supabase_project.deeptype.id}"
  sensitive   = true
}

output "deeptype_pg_password" {
  description = "deeptype_app 역할 비밀번호(TF 생성). account-vibe가 Hyperdrive origin password로 읽는다."
  value       = random_password.deeptype_app.result
  sensitive   = true
}

# account-stella 워크스페이스가 terraform_remote_state로 읽어 Hyperdrive origin user/password로 쓴다
# (Remote State Sharing: sobok-prod → account-stella 필요).
output "stella_pg_user" {
  description = "stella 런타임 역할 세션 풀러 사용자(stella_app.<project-ref>)."
  value       = "stella_app.${supabase_project.deeptype.id}"
  sensitive   = true
}

output "stella_pg_password" {
  description = "stella_app 역할 비밀번호(TF 생성). account-stella가 Hyperdrive origin password로 읽는다."
  value       = random_password.stella_app.result
  sensitive   = true
}
