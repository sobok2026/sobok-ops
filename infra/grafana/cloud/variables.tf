variable "grafana_cloud_access_policy_token" {
  description = "org 범위 리소스(스택, access policy, 스택 서비스 계정)를 관리하는 데 쓰는 Grafana Cloud access policy 토큰."
  type        = string
  nullable    = false
  sensitive   = true
}

variable "grafana_cloud_organization_slug" {
  description = "스택을 소유한 Grafana Cloud 조직 slug."
  type        = string
  nullable    = false
}

variable "grafana_cloud_region" {
  description = "스택과 access policy 의 Grafana Cloud region slug. 기존 스택이 생성된 region 과 일치해야 한다."
  type        = string
  default     = "prod-ap-northeast-0"
  nullable    = false
}

variable "grafana_stack_slug" {
  description = "기존 Grafana Cloud 스택의 서브도메인(slug), 예: https://<slug>.grafana.net 의 값."
  type        = string
  nullable    = false
}

variable "frontend_o11y_app_name" {
  description = "Frontend Observability(Faro) 앱 이름."
  type        = string
  default     = "sobok-web"
  nullable    = false
}

variable "frontend_o11y_allowed_origins" {
  description = "Frontend Observability 컬렉터의 허용 CORS origin."
  type        = list(string)
  default     = ["https://sobok.cc"]
  nullable    = false
}
