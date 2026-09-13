resource "aws_ssm_parameter" "vpc_id" {
  name  = "/oficina/network/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id
}

resource "aws_ssm_parameter" "vpc_cidr" {
  name  = "/oficina/network/vpc_cidr"
  type  = "String"
  value = module.vpc.vpc_cidr_block
}

resource "aws_ssm_parameter" "private_subnets" {
  name  = "/oficina/network/private_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.private_subnets)
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "/oficina/eks/cluster_name"
  type  = "String"
  value = module.eks.cluster_name
}

resource "random_password" "jwt" {
  for_each = toset(var.ambientes)

  length  = 48
  special = false
}

resource "random_password" "webhook" {
  for_each = toset(var.ambientes)

  length  = 32
  special = false
}

resource "random_password" "admin" {
  for_each = toset(var.ambientes)

  length  = 20
  special = false
}

resource "aws_ssm_parameter" "jwt_secret" {
  for_each = toset(var.ambientes)

  name  = "/oficina/${each.key}/jwt_secret"
  type  = "SecureString"
  value = random_password.jwt[each.key].result
}

resource "aws_ssm_parameter" "webhook_token" {
  for_each = toset(var.ambientes)

  name  = "/oficina/${each.key}/webhook_token"
  type  = "SecureString"
  value = random_password.webhook[each.key].result
}

resource "aws_ssm_parameter" "admin_password" {
  for_each = toset(var.ambientes)

  name  = "/oficina/${each.key}/admin_password"
  type  = "SecureString"
  value = random_password.admin[each.key].result
}
