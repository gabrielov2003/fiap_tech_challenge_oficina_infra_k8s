resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  depends_on = [module.eks]
}

resource "helm_release" "datadog" {
  count = local.datadog_agente ? 1 : 0

  name             = "datadog"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  namespace        = "datadog"
  create_namespace = true

  values = [yamlencode({
    datadog = {
      site        = var.datadog_site
      clusterName = var.cluster_name
      logs = {
        enabled             = true
        containerCollectAll = true
      }
      apm = {
        portEnabled = true
      }
      dogstatsd = {
        useHostPort     = true
        nonLocalTraffic = true
      }
      kubeStateMetricsCore = {
        enabled = true
      }
      processAgent = {
        enabled           = true
        processCollection = false
      }
    }
    clusterAgent = {
      enabled = true
    }
  })]

  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog_api_key
  }

  depends_on = [module.eks]
}
