# Synthetic Monitoring 전용 publisher 토큰(stacks:read + write 필요).
resource "grafana_cloud_access_policy" "sm_publisher" {
  region       = var.grafana_cloud_region
  name         = "sobok-prod-sm-publisher"
  display_name = "Sobok prod Synthetic Monitoring publisher"

  scopes = [
    "stacks:read",
    "metrics:write",
    "logs:write",
    "traces:write",
  ]

  realm {
    type       = "stack"
    identifier = grafana_cloud_stack.this.id
  }
}

resource "grafana_cloud_access_policy_token" "sm_publisher" {
  region           = var.grafana_cloud_region
  access_policy_id = grafana_cloud_access_policy.sm_publisher.policy_id
  name             = "sobok-prod-sm-publisher"
  display_name     = "Sobok prod Synthetic Monitoring publisher"
}

# SM 은 이미 활성화되어 있다; 이 리소스는 import 할 수 없지만 기존 설치에 깔끔하게 apply 되며,
# grafana.sm 프로바이더가 쓰는 SM API 토큰을 산출한다.
resource "grafana_synthetic_monitoring_installation" "this" {
  stack_id              = grafana_cloud_stack.this.id
  metrics_publisher_key = grafana_cloud_access_policy_token.sm_publisher.token
}

data "grafana_synthetic_monitoring_probes" "main" {
  provider   = grafana.sm
  depends_on = [grafana_synthetic_monitoring_installation.this]
}

resource "grafana_synthetic_monitoring_check" "web_health" {
  provider = grafana.sm

  job     = "sobok-prod-web-health"
  target  = "https://sobok.cc/health"
  enabled = true
  probes  = [data.grafana_synthetic_monitoring_probes.main.probes.Tokyo]

  labels = {
    component = "web"
    env       = "prod"
    service   = "sobok-web"
  }

  settings {
    http {}
  }
}

resource "grafana_synthetic_monitoring_check" "api_health" {
  provider = grafana.sm

  job     = "sobok-prod-api-health"
  target  = "https://sobok.cc/api/health"
  enabled = true
  probes  = [data.grafana_synthetic_monitoring_probes.main.probes.Tokyo]

  labels = {
    component = "api"
    env       = "prod"
    service   = "sobok-api"
  }

  settings {
    http {}
  }
}
