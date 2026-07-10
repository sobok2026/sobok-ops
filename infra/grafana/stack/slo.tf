# 요청을 처리하는 두 서비스의 가용성 SLO. Grafana SLO 앱을 통해 정의한다.
#
# 이는 페이징이 App Observability 의 자동 baseline 지연/이상 assertion 이 아니라 명시적 error budget 에
# 근거하도록 하기 위해 존재한다. 이 트래픽 수준(api ~5 rps, web ~1.7 rps)에서 그런 assertion 은 통계적
# 노이즈다 — 느리거나 실패한 요청 하나가 percentile 이나 비율을 뒤흔든다 — 게다가 누구에게가 아니라
# Asserts insight processor 로 라우팅된다. budget 에 대한 burn-rate 알림이야말로 실제로 주목할 만한 신호다.
#
# Bad = 서버 측 실패만(5xx / span error). 클라이언트 오류(4xx)와 rate-limit 된 요청(429)은 budget 밖에
# 두고, health/readiness probe 는 분모에서 제외해 probe 트래픽이 비율을 부풀리지도 희석하지도 않게 한다.
#
# SLI 소스는 서비스별 텔레메트리가 다르므로 서로 다르다. sobok-api(Hono on Bun)는 정확한
# http.response.status_code 를 가진 네이티브 OTel HTTP 서버 메트릭을 방출하므로 SLI 가 5xx-정밀하다.
# sobok-web(Next.js / @vercel/otel)은 HTTP 서버 메트릭을 방출하지 않는다 — 유일한 요청 신호가 trace 에서
# 파생된 span 메트릭이라 SLI 가 span-error 기반이다(STATUS_CODE_ERROR 가 서버 span 의 실패 상태, ~5xx/uncaught).
#
# Burn-rate 알림은 루트 notification policy 를 상속하며 Discord 로 전달된다.

locals {
  # 스택의 호스티드 Prometheus/Mimir 데이터소스. SLO 앱이 recording/alert 규칙을 여기에 기록한다.
  slo_destination_datasource_uid = "grafanacloud-prom"

  # health/readiness/startup probe 는 사용자 트래픽이 아니다.
  api_probe_routes = "/health|/api/health|/ready|/startup"
  web_probe_spans  = "GET /health|GET /ready|GET /startup|GET /api/health"

  # 롤링 budget 윈도우와 타깃. 물량이 적은 동안은 의도적으로 넉넉하게; 실제 트래픽이 늘면 조인다.
  slo_objective = 0.995
  slo_window    = "28d"
}

resource "grafana_slo" "api_availability" {
  name        = "sobok-api availability"
  description = "health probe 와 429 를 제외하고 5xx 로 처리되지 않은 sobok-api 요청의 비율."

  query {
    type = "freeform"
    freeform {
      query = <<-EOT
        sum(rate(http_server_request_duration_seconds_count{service_name="sobok-api", http_route!~"${local.api_probe_routes}", http_response_status_code!="429", http_response_status_code!~"5.."}[$__rate_interval]))
        /
        sum(rate(http_server_request_duration_seconds_count{service_name="sobok-api", http_route!~"${local.api_probe_routes}", http_response_status_code!="429"}[$__rate_interval]))
      EOT
    }
  }

  objectives {
    value  = local.slo_objective
    window = local.slo_window
  }

  destination_datasource {
    uid = local.slo_destination_datasource_uid
  }

  label {
    key   = "service"
    value = "sobok-api"
  }
  label {
    key   = "sli"
    value = "availability"
  }

  alerting {
    fastburn {
      label {
        key   = "severity"
        value = "critical"
      }
      annotation {
        key   = "summary"
        value = "sobok-api 가 가용성 budget 을 빠르게 소진하고 있다."
      }
    }
    slowburn {
      label {
        key   = "severity"
        value = "warning"
      }
      annotation {
        key   = "summary"
        value = "sobok-api 가 가용성 budget 을 천천히 소진하고 있다."
      }
    }
  }
}

resource "grafana_slo" "web_availability" {
  name        = "sobok-web availability"
  description = "health probe 를 제외하고 error 상태가 없는 sobok-web 서버 span 의 비율."

  query {
    type = "freeform"
    freeform {
      query = <<-EOT
        sum(rate(traces_spanmetrics_calls_total{service="sobok-web", span_kind="SPAN_KIND_SERVER", span_name!~"${local.web_probe_spans}", status_code!="STATUS_CODE_ERROR"}[$__rate_interval]))
        /
        sum(rate(traces_spanmetrics_calls_total{service="sobok-web", span_kind="SPAN_KIND_SERVER", span_name!~"${local.web_probe_spans}"}[$__rate_interval]))
      EOT
    }
  }

  objectives {
    value  = local.slo_objective
    window = local.slo_window
  }

  destination_datasource {
    uid = local.slo_destination_datasource_uid
  }

  label {
    key   = "service"
    value = "sobok-web"
  }
  label {
    key   = "sli"
    value = "availability"
  }

  alerting {
    fastburn {
      label {
        key   = "severity"
        value = "critical"
      }
      annotation {
        key   = "summary"
        value = "sobok-web 가 가용성 budget 을 빠르게 소진하고 있다."
      }
    }
    slowburn {
      label {
        key   = "severity"
        value = "warning"
      }
      annotation {
        key   = "summary"
        value = "sobok-web 가 가용성 budget 을 천천히 소진하고 있다."
      }
    }
  }
}
