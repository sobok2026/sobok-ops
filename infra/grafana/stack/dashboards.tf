# 커스텀 대시보드는 ./dashboards/*.json 파일들이다. 대시보드 JSON 모델을 거기에 넣으면 여기서
# 관리된다 — 나머지 인프라와 동일한 control plane 하나로.
resource "grafana_dashboard" "sobok" {
  for_each = fileset("${path.module}/dashboards", "*.json")

  folder      = grafana_folder.sobok.uid
  config_json = file("${path.module}/dashboards/${each.value}")
}
