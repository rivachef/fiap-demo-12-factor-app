# demo-12-factor-app

12-Factor demo app para Live com Node.js + Express, Kubernetes (kind + Helm) e GitOps com Argo CD. Pipeline de CI com GitHub Actions para build/push da imagem no Docker Hub e disparo de deploy via GitOps.

## Guia: Pipeline no EKS
Consulte o passo a passo detalhado para executar a pipeline GitHub Actions + Argo CD + EKS em:
- `docs/pipeline-eks.md`

## Guia: 12‑Factor na prática
Veja como cada fator se aplica a esta demo/hands‑on, com referências aos arquivos do repo:
- `docs/12-factor-app.md`

## Arquitetura (única)
```mermaid
flowchart LR
  Dev[Dev push] -->|git push| GH[GitHub]
  GH -->|Actions CI build/push| DH[(Docker Hub)]
  ACD[Argo CD] -->|sync| EKS[(EKS cluster)]
  DH -->|pull| AppPod[Pod Express]
  User -->|HTTP 3000| SVC[Service] --> AppPod
  K8s -->|Probes /healthz| AppPod
  AppPod -->|stdout| Logs[kubectl logs]
```

## Stack
- Node.js 20 + Express
- Docker
- Kubernetes (EKS)
- Helm
- Argo CD (GitOps)
- Docker Hub (registry)
- GitHub Actions (CI)

## Executar local (sem Kubernetes)

```bash
# Pré-requisitos: Node 20, Docker
npm install
npm start
# ou via Docker
docker build -t demo-12-factor-app:local .
docker run --rm -p 3000:3000 -e PORT=3000 demo-12-factor-app:local
# Teste
curl http://localhost:3000/healthz
```

## EKS via CloudFormation (recomendado)

Se preferir usar CloudFormation puro (permitido no Learner Lab), o repositório inclui templates em `cloudformation/` e scripts de automação.

1. Pré-requisitos
```bash
aws --version
kubectl version --client
```

2. Variáveis obrigatórias
```bash
export AWS_REGION=us-east-1 # ou us-west-2
export CLUSTER_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/LabEksClusterRole
export NODE_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/LabEksNodeRole
```

3. (Opcional) Informar rede explicitamente
```bash
# Caso não queira autodiscovery da VPC default:
export SUBNET_IDS=subnet-aaaa,subnet-bbbb
export SECURITY_GROUP_IDS=sg-zzzzzz
```

4. Provisionar cluster e nodegroup
```bash
chmod +x scripts/deploy-cfn.sh scripts/destroy-cfn.sh
scripts/deploy-cfn.sh
```

5. Acessar a aplicação
```bash
kubectl -n demo-12-factor-app port-forward svc/demo-12-factor-app 3000:80
curl http://localhost:3000/healthz
```

6. Teardown para economizar orçamento
```bash
scripts/destroy-cfn.sh
```

## CI: GitHub Actions + Docker Hub

1. Criar secrets no repositório GitHub:
- `DOCKERHUB_USERNAME`: seu usuário do Docker Hub
- `DOCKERHUB_TOKEN`: um Access Token do Docker Hub (ou senha, não recomendado)

2. Ajustar chart Helm
- Edite `helm/demo-12-factor-app/values.yaml` e troque `REPLACE_ME_YOUR_DOCKERHUB_USERNAME` pelo seu usuário.

3. Fluxo
- Ao fazer push na branch `main`, a pipeline:
  - builda a imagem `docker.io/<username>/demo-12-factor-app`
  - publica tags: `latest` (na main), `sha-<shortsha>` e de branch
  - atualiza `helm/demo-12-factor-app/values.yaml` com a nova tag (`sha-<shortsha>`) e commita
  - Argo CD detecta a mudança e sincroniza o cluster

## 12-Factor demonstrados
- Codebase: repositório único
- Dependencies: declaradas em `package.json`
- Config: variáveis de ambiente via `ConfigMap`/`Secret`
- Backing services: `DATABASE_URL` (opcional, para adicionar banco depois)
- Build, release, run: imagem versionada + Argo CD aplica novo release
- Processes: stateless (dados na memória por enquanto)
- Port binding: HTTP escutando `PORT`
- Concurrency: `replicaCount` e HPA (opcional)
- Disposability: graceful shutdown com SIGTERM/SIGINT
- Dev/prod parity: Docker local x EKS
- Logs: stdout (kubectl logs)
- Admin processes: Job de migrations (template, opcional)

## Extensões futuras (opcional)
- Postgres (RDS ou Helm chart) e migrations (`migrations.enabled: true`)
- EKS com a mesma Application (ajustando `destination.server` e ingress)

## Troubleshooting
- Se o cluster não puxa a imagem do Docker Hub, verifique `imagePullPolicy` e se o `values.yaml` está com `repository` correto.
- Em ambientes com IAM restrito (Learner Lab), prefira `kubectl port-forward` em vez de instalar Ingress/ALB. 
- Para encerrar custos, sempre destrua o cluster com `scripts/destroy-cfn.sh` quando não estiver usando.
