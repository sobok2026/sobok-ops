# 대응 불필요한 라우트를 억제하는 상시 mute(매일 24시간).
resource "grafana_mute_timing" "always" {
  name = "always"

  intervals {
    times {
      start = "00:00"
      end   = "24:00"
    }
  }
}

# 루트 라우팅 트리. 대응 가능한 severity 에만 알린다:
#   critical -> critical 채널, warning(및 미매칭) -> warning 채널,
#   info     -> 억제(수다스러운 통합 integration 신호가 여기 들어온다).
resource "grafana_notification_policy" "root" {
  group_by      = ["grafana_folder", "alertname"]
  contact_point = grafana_contact_point.discord_warning.name

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  policy {
    contact_point = grafana_contact_point.discord_critical.name

    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }
  }

  policy {
    contact_point = grafana_contact_point.discord_warning.name
    mute_timings  = [grafana_mute_timing.always.name]

    matcher {
      label = "severity"
      match = "="
      value = "info"
    }
  }
}
