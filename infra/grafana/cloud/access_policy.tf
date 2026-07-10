# Mac Mini 의 앱 컨테이너가 metrics / logs / traces / profiles 를 Grafana Cloud 로 OTLP 전송할 때 쓰는
# 최소 권한 write-only 정책. 토큰은 SOPS 시크릿의 OTEL_EXPORTER_OTLP_HEADERS 로 앱에 전달된다.
resource "grafana_cloud_access_policy" "collector_write" {
  region       = var.grafana_cloud_region
  name         = "sobok-prod-collector-write"
  display_name = "Sobok prod collector (write)"

  scopes = [
    "metrics:write",
    "logs:write",
    "traces:write",
    "profiles:write",
  ]

  realm {
    type       = "stack"
    identifier = grafana_cloud_stack.this.id
  }
}

resource "grafana_cloud_access_policy_token" "collector_write" {
  region           = var.grafana_cloud_region
  access_policy_id = grafana_cloud_access_policy.collector_write.policy_id
  name             = "sobok-prod-collector-write"
  display_name     = "Sobok prod collector (write)"
}
