# 12‑Factor App na prática (Demo/Hands‑on)

Este documento resume os 12 fatores e mostra exatamente onde a nossa aplicação de demo aplica cada um deles. Referências de arquivos e manifestos do repositório são indicadas em cada seção.

Referência oficial: https://12factor.net/

---

## I. Codebase
- O que é: Uma codebase por app, versionada, muitos deploys.
- Como aplicamos:
  - Repositório único com todo o código e infraestrutura de app: `src/`, `helm/demo-12-factor-app/`, `argocd/application.yaml`, `.github/workflows/ci.yaml`.
  - Variações de ambiente são feitas por configuração (values/env), não por forks.

## II. Dependencies
- O que é: Dependências explicitamente declaradas e isoladas.
- Como aplicamos:
  - `package.json` com `express` e `engines` (Node >= 20).
  - Lockfile gerado via `npm install` (recomendado commitar `package-lock.json`).
  - Container isolando runtime: `Dockerfile`.

## III. Config
- O que é: Configurações em variáveis de ambiente, separadas do código.
- Como aplicamos:
  - Exemplos locais: `.env.example`.
  - Kubernetes: `helm/demo-12-factor-app/templates/configmap.yaml` (não sensível). `templates/secret.yaml` é opcional e só renderiza se houver chaves em `.Values.secret`.
  - Valores definidos em `helm/demo-12-factor-app/values.yaml` (ex.: `env`, `config`).
  - No pipeline, somente `image.tag` é alterado; configs podem ser alteradas via GitOps sem rebuild.

## IV. Backing services
- O que é: Serviços de apoio (DB, cache, filas) tratados como recursos anexados.
- Como aplicamos:
  - Nesta demo, não usamos banco de dados nem serviços externos por padrão.
  - Quando necessário, adicione variáveis (ex.: `DATABASE_URL`) via Secret e ajuste o app para consumi‑las.

## V. Build, release, run
- O que é: Separação clara das fases de build, release e run.
- Como aplicamos:
  - Build: `.github/workflows/ci.yaml` cria a imagem e publica no Docker Hub (`docker/build-push-action`).
  - Release: versão do deploy controlada por `image.tag` em `helm/demo-12-factor-app/values.yaml` (atualizado para `sha-<commit>`).
  - Run: Argo CD aplica/atualiza o `Deployment` no cluster, gerenciando releases.

## VI. Processes
- O que é: Execução como processos stateless; compartilhamento por backing services.
- Como aplicamos:
  - App HTTP stateless em `src/index.js` (dados in-memory apenas para demo).
  - Escalável via réplica de Pods; estado persistente deve ir para serviços (DB, cache) quando habilitados.

## VII. Port binding
- O que é: O app exporta serviços via binding de porta.
- Como aplicamos:
  - Express escuta `process.env.PORT` (padrão 3000) em `src/index.js`.
  - Service expõe a porta via `helm/.../templates/service.yaml`. Por padrão, `type: LoadBalancer` cria um NLB no EKS; alternativamente, pode‑se usar `kubectl port-forward` durante o desenvolvimento.

## VIII. Concurrency
- O que é: Dimensionamento por processos (ou réplicas) de forma horizontal.
- Como aplicamos:
  - Réplicas configuráveis por `replicaCount` em `values.yaml`.
  - HPA não está incluído no starter; pode ser adicionado futuramente.

## IX. Disposability
- O que é: Início/parada rápidos; shutdown gracioso.
- Como aplicamos:
  - Tratamento de `SIGTERM`/`SIGINT` em `src/index.js` (graceful shutdown) com `server.close()` e timeout de fallback.
  - `Deployment` com strategy rolling update para trocas rápidas.

## X. Dev/prod parity
- O que é: Manter paridade entre ambientes para reduzir divergências.
- Como aplicamos:
  - Mesmo container e mesmo chart de deploy para local (Docker) e EKS; diferenças concentradas em configuração.
  - GitOps garante que o manifesto versionado é a fonte de verdade.

## XI. Logs
- O que é: Tratar logs como fluxo de eventos, enviados para stdout/stderr.
- Como aplicamos:
  - `console.log` em `src/index.js` (stdout).
  - Observação em cluster via `kubectl logs -f deployment/demo-12-factor-app -n demo-12-factor-app`.

## XII. Admin processes
- O que é: Tarefas administrativas em processos pontuais, separados do processo web.
- Como aplicamos:
  - Não incluímos templates de `Job` neste starter. Quando necessário, adicione um `Job` específico para migrations, seeds ou tarefas batch sem acoplar ao processo web.

---

## Endpoints e observabilidade na demo
- Healthcheck: `GET /healthz` (probes configuradas em `values.yaml` via `probes.*`).
- Recursos de exemplo: `GET /quotes`, `POST /quotes`, `DELETE /quotes/:id`.
- Logs: stdout (via `kubectl logs`).

## Fluxo CI/CD (resumo)
1. Commit no GitHub → Workflow CI builda e publica a imagem no Docker Hub.
2. CI atualiza `image.tag` em `helm/demo-12-factor-app/values.yaml` com `sha-<commit>`.
3. Argo CD detecta alteração no repositório e sincroniza o cluster (deploy/rollback via GitOps).

## Dicas para a Live
- Demonstre alteração de configuração (ex.: `LOG_LEVEL`) apenas via `values.yaml` e GitOps.
- Escalone réplicas com um `git commit` alterando `replicaCount`.
- Mostre `SIGTERM` (delete pod) e como o shutdown é limpo.
- Se quiser avançar, habilite Ingress e/ou Postgres para evidenciar Backing Services e Admin Processes.
