# Argo CD Manifests

O manifesto canônico do Argo CD é:

- `argocd/application.yaml` (aponta para o chart `helm/demo-12-factor-app` e usa `values.yaml`)

Observações:

- Overlays de valores usados pelo Argo CD devem ficar dentro do diretório do chart.
- Este projeto consolidado utiliza apenas `helm/demo-12-factor-app/values.yaml` por padrão.
