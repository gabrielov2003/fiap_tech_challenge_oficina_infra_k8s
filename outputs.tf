output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = one(module.eks[*].cluster_endpoint)
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "ecr_api_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecr_servicos_url" {
  value = { for nome, repositorio in aws_ecr_repository.servicos : nome => repositorio.repository_url }
}

output "datadog_dashboard_url" {
  value = one(datadog_dashboard.oficina[*].url)
}
