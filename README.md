# fiap_tech_challenge_oficina_infra_k8s

Infraestrutura como código (Terraform) do cluster Kubernetes utilizado pela aplicação da oficina. Provisiona o cluster onde roda a aplicação principal do repositório `fiap_tech_challenge_oficina_api`.

## Tecnologias utilizadas

* Terraform, provisionamento de infraestrutura
* AWS EKS, cluster Kubernetes gerenciado
* AWS VPC, rede dedicada ao cluster
* GitHub Actions, pipeline de CI/CD

## O que é provisionado

* `module.vpc`: VPC dedicada com subnets públicas e privadas em 2 zonas de disponibilidade, e NAT Gateway para acesso à internet dos nós privados
* `module.eks`: cluster EKS 1.30, com node group gerenciado em instâncias `t3.small` (1 a 3 nós, desejado 2)

## Como provisionar

Pré-requisitos: Terraform instalado e AWS CLI configurado com credenciais válidas (`aws configure`).

```bash
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --region us-east-1 --name oficina-cluster
```

Depois de provisionado, o cluster fica pronto para receber os manifestos de deploy da aplicação, mantidos no repositório `fiap_tech_challenge_oficina_api` (`kubectl apply -f k8s/`).

## Variáveis

| Variável | Descrição | Padrão |
|---|---|---|
| `region` | Região AWS | `us-east-1` |
| `cluster_name` | Nome do cluster EKS | `oficina-cluster` |

## Outputs

| Output | Descrição |
|---|---|
| `cluster_name` | Nome do cluster criado |
| `cluster_endpoint` | Endpoint de acesso ao cluster |
| `configure_kubectl` | Comando pronto para configurar o kubectl local |
| `vpc_id` | Id da VPC criada, útil para conectar outros recursos (como o banco de dados gerenciado) à mesma rede |
| `private_subnets` | Ids das subnets privadas do cluster |

## CI/CD

O pipeline em `.github/workflows/ci-cd.yml` roda em pull requests e a cada push em `main`:

| Etapa | O que faz |
|---|---|
| `fmt` / `validate` | Verifica formatação e validade do código Terraform |
| `plan` | Mostra as mudanças propostas, roda apenas se houver credenciais AWS configuradas |
| `apply` | Aplica as mudanças, roda apenas em push para `main` e se houver credenciais AWS configuradas |

Secrets necessários no GitHub (Settings, Secrets and variables, Actions):

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Chave de acesso da AWS |
| `AWS_SECRET_ACCESS_KEY` | Chave secreta da AWS |

Sem essas credenciais configuradas, o pipeline roda normalmente até a validação e ignora as etapas de plan e apply.

## Documentação

O diagrama de arquitetura específico deste repositório será adicionado aqui conforme a Fase 3 avança.

---
Este projeto faz parte do Tech Challenge da Pós Graduação em Arquitetura de Software da FIAP.
