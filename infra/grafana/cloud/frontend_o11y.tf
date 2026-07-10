# Frontend Observability(Faro) 앱 등록. 브라우저 SDK 가 export 된 collector_endpoint 로 전송한다.
# 이 리소스는 깔끔하게 import 할 수 없으므로, 채택하려면 web 앱의 Faro 설정을 이 앱의
# collector_endpoint 로 향하게 한다.
resource "grafana_frontend_o11y_app" "sobok" {
  stack_id        = grafana_cloud_stack.this.id
  name            = var.frontend_o11y_app_name
  allowed_origins = var.frontend_o11y_allowed_origins

  extra_log_attributes = {
    service = var.frontend_o11y_app_name
  }

  settings = {
    "geolocation.enabled" = "0"
  }
}
