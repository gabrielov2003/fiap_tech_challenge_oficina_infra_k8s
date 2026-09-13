locals {
  notificacao = var.datadog_alert_email == "" ? "" : "@${var.datadog_alert_email}"
}

resource "datadog_dashboard" "oficina" {
  count = local.datadog_monitoramento ? 1 : 0

  title       = "Oficina, visão operacional"
  description = "Ordens de serviço, API, Kubernetes e integrações"
  layout_type = "ordered"

  template_variable {
    name     = "env"
    prefix   = "env"
    defaults = ["prod"]
  }

  widget {
    query_value_definition {
      title     = "Ordens de serviço abertas nas últimas 24 horas"
      live_span = "1d"
      precision = 0

      request {
        q          = "sum:oficina.os.abertas{$env}.as_count()"
        aggregator = "sum"
      }
    }
  }

  widget {
    timeseries_definition {
      title     = "Volume diário de ordens de serviço"
      live_span = "1w"

      request {
        q            = "sum:oficina.os.abertas{$env}.as_count().rollup(sum, 86400)"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Tempo médio em cada status da OS (segundos)"

      request {
        q            = "avg:oficina.os.tempo_status{$env} by {status}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Latência média da API por endpoint (segundos)"

      request {
        q            = "avg:trace.flask.request.duration{service:oficina-api,$env} by {resource_name}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Requisições e erros da API"

      request {
        q            = "sum:trace.flask.request.hits{service:oficina-api,$env}.as_count()"
        display_type = "bars"
      }

      request {
        q            = "sum:trace.flask.request.errors{service:oficina-api,$env}.as_count()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "CPU dos pods da API (nanocores)"

      request {
        q            = "sum:kubernetes.cpu.usage.total{kube_deployment:oficina-api,$env} by {pod_name}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Memória dos pods da API (bytes)"

      request {
        q            = "sum:kubernetes.memory.usage{kube_deployment:oficina-api,$env} by {pod_name}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Réplicas disponíveis da API (HPA)"

      request {
        q            = "avg:kubernetes_state.deployment.replicas_available{kube_deployment:oficina-api,$env}"
        display_type = "line"
      }
    }
  }

  widget {
    check_status_definition {
      title    = "Healthcheck da API"
      check    = "http.can_connect"
      grouping = "cluster"
      tags     = ["service:oficina-api", "$env"]
    }
  }

  widget {
    timeseries_definition {
      title = "Falhas no processamento de ordens de serviço"

      request {
        q            = "sum:oficina.os.falhas{$env} by {operacao}.as_count()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Erros e falhas nas integrações (webhook e Lambda)"

      request {
        q            = "sum:oficina.integracao.erros{$env} by {integracao,motivo}.as_count()"
        display_type = "bars"
      }

      request {
        q            = "sum:aws.lambda.enhanced.errors{service:oficina-auth,$env}.as_count()"
        display_type = "bars"
      }
    }
  }
}

resource "datadog_monitor" "falhas_os" {
  count = local.datadog_monitoramento ? 1 : 0

  name                = "[Oficina] Falhas no processamento de ordens de serviço"
  type                = "query alert"
  query               = "sum(last_5m):sum:oficina.os.falhas{*} by {env}.as_count() > 3"
  message             = "Falhas no processamento de ordens de serviço acima do limite no ambiente {{env.name}}. ${local.notificacao}"
  require_full_window = false
  tags                = ["service:oficina-api", "projeto:oficina"]

  monitor_thresholds {
    warning  = 1
    critical = 3
  }
}

resource "datadog_monitor" "latencia_api" {
  count = local.datadog_monitoramento ? 1 : 0

  name    = "[Oficina] Latência alta na API"
  type    = "query alert"
  query   = "avg(last_10m):avg:trace.flask.request.duration{service:oficina-api} by {env} > 1"
  message = "Latência média da API acima de 1 segundo no ambiente {{env.name}}. ${local.notificacao}"
  tags    = ["service:oficina-api", "projeto:oficina"]

  monitor_thresholds {
    warning  = 0.5
    critical = 1
  }
}

resource "datadog_monitor" "healthcheck_api" {
  count = local.datadog_monitoramento ? 1 : 0

  name    = "[Oficina] API fora do ar (healthcheck)"
  type    = "service check"
  query   = "\"http.can_connect\".over(\"service:oficina-api\").by(\"env\").last(3).count_by_status()"
  message = "O healthcheck da API falhou no ambiente {{env.name}}. ${local.notificacao}"
  tags    = ["service:oficina-api", "projeto:oficina"]

  monitor_thresholds {
    ok       = 1
    warning  = 1
    critical = 2
  }
}

resource "datadog_monitor" "cpu_api" {
  count = local.datadog_monitoramento ? 1 : 0

  name    = "[Oficina] Consumo de CPU alto nos pods da API"
  type    = "query alert"
  query   = "avg(last_10m):avg:kubernetes.cpu.usage.total{kube_deployment:oficina-api} by {env} > 400000000"
  message = "Os pods da API estão usando mais de 0,4 vCPU em média no ambiente {{env.name}}. ${local.notificacao}"
  tags    = ["service:oficina-api", "projeto:oficina"]

  monitor_thresholds {
    warning  = 300000000
    critical = 400000000
  }
}

resource "datadog_monitor" "erros_integracao" {
  count = local.datadog_monitoramento ? 1 : 0

  name                = "[Oficina] Erros nas integrações"
  type                = "query alert"
  query               = "sum(last_10m):sum:oficina.integracao.erros{*} by {env}.as_count() > 5"
  message             = "Erros de integração (webhook) acima do limite no ambiente {{env.name}}. ${local.notificacao}"
  require_full_window = false
  tags                = ["service:oficina-api", "projeto:oficina"]

  monitor_thresholds {
    warning  = 2
    critical = 5
  }
}

resource "datadog_monitor" "erros_lambda" {
  count = local.datadog_monitoramento ? 1 : 0

  name                = "[Oficina] Erros na Lambda de autenticação"
  type                = "query alert"
  query               = "sum(last_10m):sum:aws.lambda.enhanced.errors{service:oficina-auth} by {env}.as_count() > 3"
  message             = "A Lambda de autenticação por CPF está falhando no ambiente {{env.name}}. ${local.notificacao}"
  require_full_window = false
  tags                = ["service:oficina-auth", "projeto:oficina"]

  monitor_thresholds {
    warning  = 1
    critical = 3
  }
}
