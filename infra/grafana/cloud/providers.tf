provider "grafana" {
  cloud_access_policy_token = var.grafana_cloud_access_policy_token
}

# Synthetic Monitoring API 프로바이더. installation 리소스로 인증한다.
provider "grafana" {
  alias           = "sm"
  sm_url          = grafana_synthetic_monitoring_installation.this.stack_sm_api_url
  sm_access_token = grafana_synthetic_monitoring_installation.this.sm_access_token
}
