# grafana-stack-prod 워크스페이스의 in-stack 프로바이더(알림, 폴더, 대시보드, SLO)를 인증하는
# 토큰을 가진 Admin 서비스 계정.
resource "grafana_cloud_stack_service_account" "terraform" {
  stack_slug  = grafana_cloud_stack.this.slug
  name        = "terraform-stack"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_cloud_stack_service_account_token" "terraform" {
  stack_slug         = grafana_cloud_stack.this.slug
  name               = "terraform-stack"
  service_account_id = grafana_cloud_stack_service_account.terraform.id
}
