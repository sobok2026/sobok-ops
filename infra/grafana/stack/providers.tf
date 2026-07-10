# 스택 URL 과 admin 서비스 계정 토큰은 grafana-cloud 워크스페이스가 산출한다.
# 이 워크스페이스에는 grafana-cloud 에 대한 remote-state 읽기만 부여한다.
data "terraform_remote_state" "grafana_cloud" {
  backend = "remote"

  config = {
    organization = "sobok"
    workspaces = {
      name = "grafana-cloud"
    }
  }
}

provider "grafana" {
  url  = data.terraform_remote_state.grafana_cloud.outputs.stack_url
  auth = data.terraform_remote_state.grafana_cloud.outputs.stack_service_account_token
}
