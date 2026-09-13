variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "oficina-cluster"
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC compartilhada pelo cluster, pelo banco e pela Lambda"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_type" {
  description = "Tipo de instância dos nós do cluster"
  type        = string
  default     = "c7i-flex.large"
}

variable "ambientes" {
  description = "Ambientes lógicos que compartilham o cluster, cada um com seu namespace e seus segredos"
  type        = list(string)
  default     = ["dev", "prod"]
}

variable "admin_principal_arns" {
  description = "ARNs IAM extras com acesso de administrador ao cluster, além de quem o criou"
  type        = list(string)
  default     = []
}

variable "datadog_api_key" {
  description = "API key do Datadog, habilita o agente no cluster"
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Application key do Datadog, habilita a criação do dashboard e dos alertas"
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_site" {
  description = "Site do Datadog da conta"
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_alert_email" {
  description = "Email que recebe as notificações dos alertas, opcional"
  type        = string
  default     = ""
}
