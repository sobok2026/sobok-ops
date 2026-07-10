output "stack_url" {
  description = "Grafana 스택 루트 URL. grafana-stack-prod 가 in-stack 프로바이더용으로 사용한다."
  value       = grafana_cloud_stack.this.url
}

output "stack_slug" {
  description = "Grafana 스택 slug."
  value       = grafana_cloud_stack.this.slug
}

output "stack_service_account_token" {
  description = "grafana-stack-prod 가 in-stack 프로바이더용으로 사용하는 Admin 서비스 계정 토큰."
  value       = grafana_cloud_stack_service_account_token.terraform.key
  sensitive   = true
}

output "frontend_o11y_collector_endpoint" {
  description = "브라우저 SDK 용 Faro 컬렉터 URL. web 앱의 Faro 설정을 여기로 향하게 한다."
  value       = grafana_frontend_o11y_app.sobok.collector_endpoint
}

# Mac Mini 앱의 OTLP 자격증명(SOPS 시크릿 OTEL_EXPORTER_OTLP_HEADERS 로 전달). signal 별 username 은
# 스택 ingest 사용자 id, password 는 공유 write 토큰이다. 토큰 로테이션 = grafana-cloud apply.
output "collector_credentials" {
  description = "Grafana Cloud OTLP 전송용 collector basic-auth 자격증명(SOPS 시크릿에 사용)."
  sensitive   = true
  value = {
    GRAFANA_CLOUD_METRICS_USERNAME  = grafana_cloud_stack.this.prometheus_user_id
    GRAFANA_CLOUD_METRICS_PASSWORD  = grafana_cloud_access_policy_token.collector_write.token
    GRAFANA_CLOUD_LOGS_USERNAME     = grafana_cloud_stack.this.logs_user_id
    GRAFANA_CLOUD_LOGS_PASSWORD     = grafana_cloud_access_policy_token.collector_write.token
    GRAFANA_CLOUD_PROFILES_USERNAME = grafana_cloud_stack.this.profiles_user_id
    GRAFANA_CLOUD_PROFILES_PASSWORD = grafana_cloud_access_policy_token.collector_write.token
  }
}
