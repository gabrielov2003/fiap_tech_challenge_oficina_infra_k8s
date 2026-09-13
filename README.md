# fiap_tech_challenge_oficina_infra_k8s

Infraestrutura como código (Terraform) da base compartilhada da oficina: rede, cluster Kubernetes, registro de imagens, segredos por ambiente e monitoramento com Datadog. Este é um dos 4 repositórios do Tech Challenge Fase 3:

| Repositório | Responsabilidade |
|---|---|
| `fiap_tech_challenge_oficina_api` | Aplicação principal, executando em Kubernetes |
| `fiap_tech_challenge_oficina_auth_lambda` | Function de autenticação via CPF e API Gateway |
| `fiap_tech_challenge_oficina_infra_k8s` | Este repositório. Rede, cluster, registro de imagens e monitoramento |
| `fiap_tech_challenge_oficina_infra_database` | Terraform do banco de dados gerenciado |

## Tecnologias utilizadas

* Terraform, com estado remoto no S3
* AWS VPC, EKS, ECR e SSM Parameter Store
* Helm (metrics server e agente do Datadog)
* Datadog (agente, dashboard e alertas como código)
* GitHub Actions

## O que é provisionado

* `main.tf`
  * VPC com subnets públicas e privadas em 2 zonas de disponibilidade, NAT Gateway e as tags que o Kubernetes usa para criar LoadBalancers
  * Cluster EKS 1.34 com node group gerenciado (Amazon Linux 2023, `c7i-flex.large`, 1 a 3 nós, desejado 2)
  * Repositório ECR `oficina-api`, com scan de vulnerabilidades e política que mantém as 20 imagens mais recentes
* `kubernetes.tf`
  * Metrics server, necessário para o HorizontalPodAutoscaler da API funcionar
  * Agente do Datadog com logs, APM, DogStatsD, métricas de estado do Kubernetes e cluster agent
* `datadog.tf`
  * Dashboard "Oficina, visão operacional": volume diário de OS, tempo médio em cada status, latência por endpoint, requisições e erros, CPU e memória dos pods, réplicas do HPA, healthcheck, falhas no processamento de OS e erros de integração
  * Alertas: falhas no processamento de OS, latência alta, API fora do ar, CPU alta nos pods, erros no webhook e erros na Lambda
* `ssm.tf`
  * Parâmetros que os outros repositórios leem e segredos gerados para cada ambiente

## Parâmetros publicados no SSM

| Parâmetro | Tipo | Quem usa |
|---|---|---|
| `/oficina/network/vpc_id` | String | infra_database e auth_lambda |
| `/oficina/network/vpc_cidr` | String | infra_database, para liberar o banco para a VPC |
| `/oficina/network/private_subnet_ids` | StringList | infra_database e auth_lambda |
| `/oficina/eks/cluster_name` | String | Pipeline da API |
| `/oficina/<env>/jwt_secret` | SecureString | API (validação) e Lambda (assinatura) |
| `/oficina/<env>/webhook_token` | SecureString | API |
| `/oficina/<env>/admin_password` | SecureString | API, senha inicial do usuário admin |

Os segredos são gerados aleatoriamente pelo Terraform para `dev` e `prod`, então nenhum valor sensível fica em repositório ou em secret do GitHub.

## Ambientes

A infraestrutura é única e compartilhada. Os ambientes `dev` e `prod` são separados logicamente: cada um tem seu namespace no cluster, seu schema no banco, seus segredos e sua Lambda e API Gateway. Por isso, neste repositório a branch `dev` roda apenas o `plan`, e a `main` aplica as mudanças.

## Pré-requisito: bucket do estado do Terraform

Crie uma vez o bucket S3 que guarda o estado dos três repositórios de Terraform (o nome precisa ser único na AWS):

```bash
aws s3api create-bucket --bucket NOME_DO_BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket NOME_DO_BUCKET --versioning-configuration Status=Enabled
```

## Como provisionar manualmente

Pré-requisitos: Terraform 1.10+, AWS CLI configurado (`aws configure`) e, opcionalmente, as chaves do Datadog.

```bash
terraform init -backend-config="bucket=NOME_DO_BUCKET" -backend-config="key=infra-k8s/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="use_lockfile=true"
terraform apply -target=module.vpc -target=module.eks
terraform apply
aws eks update-kubeconfig --region us-east-1 --name oficina-cluster
```

O primeiro `apply` com `-target` cria a rede e o cluster antes dos recursos que dependem dele (Helm).

## Dashboard e alertas a partir da máquina local

Para demonstrar o monitoramento sem subir a infraestrutura na AWS, é possível criar apenas o dashboard e os alertas do Datadog com estado local, usando os dados enviados pelo `docker-compose.datadog.yml` da API (tag `env:local`). Esse caminho não precisa de credenciais AWS:

```bash
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
export TF_VAR_datadog_api_key=SUA_API_KEY TF_VAR_datadog_app_key=SUA_APP_KEY TF_VAR_datadog_site=datadoghq.com
terraform init
terraform apply -target=datadog_dashboard.oficina -target=datadog_monitor.falhas_os -target=datadog_monitor.erros_integracao -target=datadog_monitor.latencia_api -target=datadog_monitor.healthcheck_api
```

No dashboard, troque a variável `env` para `local`. Depois da demonstração, rode o mesmo comando trocando `apply` por `destroy` e apague o `backend_override.tf` e a pasta `.terraform`. O arquivo de override fica fora do Git.

## Variáveis

| Variável | Descrição | Padrão |
|---|---|---|
| `region` | Região AWS | `us-east-1` |
| `cluster_name` | Nome do cluster EKS | `oficina-cluster` |
| `cluster_version` | Versão do Kubernetes | `1.34` |
| `vpc_cidr` | CIDR da VPC | `10.0.0.0/16` |
| `node_instance_type` | Tipo de instância dos nós, precisa estar na lista Free Tier se a conta AWS estiver no plano gratuito | `c7i-flex.large` |
| `ambientes` | Ambientes lógicos | `["dev", "prod"]` |
| `admin_principal_arns` | ARNs IAM extras com acesso de administrador ao cluster | `[]` |
| `datadog_api_key` | API key do Datadog, sem ela o agente não é instalado | |
| `datadog_app_key` | Application key do Datadog, sem ela dashboard e alertas não são criados | |
| `datadog_site` | Site do Datadog | `datadoghq.com` |
| `datadog_alert_email` | Email notificado pelos alertas | |

Quem cria o cluster já recebe acesso de administrador. Se você aplicar localmente com um usuário diferente do usado no GitHub Actions, inclua o ARN do usuário do pipeline em `admin_principal_arns`.

## Outputs

| Output | Descrição |
|---|---|
| `cluster_name` e `cluster_endpoint` | Dados do cluster |
| `configure_kubectl` | Comando para configurar o kubectl local |
| `vpc_id` e `private_subnets` | Rede criada |
| `ecr_api_url` | Endereço do repositório de imagens da API |
| `datadog_dashboard_url` | Caminho do dashboard no Datadog |

## CI/CD

O pipeline em `.github/workflows/ci-cd.yml`:

| Job | Quando roda | O que faz |
|---|---|---|
| `validate` | Pull requests para `main` ou `dev`, e pushes | `terraform fmt` e `terraform validate` |
| `terraform` | Depois do validate | `plan` em pull requests e na branch `dev`, `apply` no push para `main` |

Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DD_API_KEY` e `DD_APP_KEY`. Variáveis: `TF_STATE_BUCKET`, e opcionais `AWS_REGION`, `DD_SITE` e `DD_ALERT_EMAIL`. Sem credenciais AWS, o pipeline para depois da validação.

## Ordem de deploy e custos

Ordem do primeiro deploy: este repositório, depois `infra_database`, a API e por último a `auth_lambda`.

EKS, NAT Gateway, LoadBalancers e RDS são cobrados por hora e não entram no free tier. Depois da demonstração, destrua na ordem inversa: `terraform destroy` na `auth_lambda` (para cada ambiente), `kubectl delete namespace dev prod` para remover os LoadBalancers criados pelo Kubernetes, `terraform destroy` no `infra_database` e por último neste repositório.

## Documentação

O diagrama de arquitetura deste repositório será adicionado aqui.

---
Este projeto faz parte do Tech Challenge da Pós Graduação em Arquitetura de Software da FIAP.
