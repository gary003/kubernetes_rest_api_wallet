# wallet-app

Kubernetes-native REST API (Node.js/TypeScript) + MySQL + auto-scaling + full observability stack.

## TL;DR

```bash
git clone https://github.com/gary003/kubernetes_rest_api_wallet.git && cd $_
minikube start --cpus=4 --memory=6g --addons=ingress
make deploy
open http://wallet.local/api/v1/doc3/apiDocumentation  # API
open http://wallet.local:3000                          # Grafana
```

## Contents

- [High-level view](#high-level-view)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Day-2 operations](#day-2-operations)
- [Observability](#observability)
- [CI/CD hints](#cicd-hints)
- [Troubleshooting](#troubleshooting)

## High-level view

```
Ingress (nginx) → wallet-api (3 pods, HPA 2-10) → MySQL (1 pod)
                        ↓
               Grafana + Prometheus + Tempo + Loki
```

## Prerequisites

| tool     | version | purpose             |
| -------- | ------- | ------------------- |
| kubectl  | ≥1.25   | cluster interaction |
| minikube | ≥1.32   | local cluster       |
| docker   | ≥20     | build/push images   |
| make     | any     | task runner         |

## Quick start

1. **Cluster**

```bash
minikube start --cpus=4 --memory=6g --addons=ingress --addons=storage-provisioner
echo "$(minikube ip) wallet.local" | sudo tee -a /etc/hosts
```

2. **Deploy**

```bash
make deploy        # validated full deploy
# OR
make deploy-quick  # dev inner-loop
```

3. **Verify**

```bash
make status        # pods ready?
make logs          # tail api logs
```

## Day-2 operations

| task                  | command                                                      |
| --------------------- | ------------------------------------------------------------ |
| manual scale          | `kubectl scale deploy/wallet-api --replicas=5 -n wallet-app` |
| view HPA              | `kubectl get hpa -n wallet-app`                              |
| rolling restart       | `make restart`                                               |
| port-forward (dev)    | `make port-forward`                                          |
| delete all (keep PVC) | `make delete`                                                |
| full wipe             | `make clean`                                                 |

## Observability

| service    | url (port-forward)    | creds           |
| ---------- | --------------------- | --------------- |
| Grafana    | http://localhost:3000 | anonymous Admin |
| Prometheus | http://localhost:9090 | n/a             |
| Tempo      | http://localhost:3200 | n/a             |
| Loki       | http://localhost:3100 | n/a             |

Pre-loaded dashboards: USE, RED, service-graph.

## CI/CD hints

1. **Build**

```bash
docker build -t ghcr.io/your-org/wallet-api:$GITHUB_SHA .
docker push ghcr.io/your-org/wallet-api:$GITHUB_SHA
```

2. **Kustomize overlay**  
   `overlays/stage/kustomization.yaml`

```yaml
images:
  - name: gary003/rest_api_nodejs_typescript
    newTag: $GITHUB_SHA
```

3. **GitOps**  
   Point ArgoCD/Flux to `./environments/<stage|prod>`.

## Troubleshooting

| symptom                      | check                                      | fix                                                            |
| ---------------------------- | ------------------------------------------ | -------------------------------------------------------------- |
| `CreateContainerConfigError` | `kubectl describe pod` → missing CM/Secret | `kubectl apply -f ./base/`                                     |
| `ImagePullBackOff`           | `docker manifest inspect <tag>`            | build & push correct arch                                      |
| HPA silent                   | `kubectl get hpa`                          | enable metrics-server: `minikube addons enable metrics-server` |
| MySQL perm denied            | pod logs                                   | remove `40_permissiion.sh` or use initContainer                |
| ingress 502                  | `kubectl get ing -n wallet-app`            | ensure `wallet.local` resolves to cluster                      |

## Contributing

PRs welcome. Run `make validate` before commit.

## Developer

- Gary Johnson
  - Mail: gary.johnson.top@gmail.com
  - Github: https://github.com/gary003
  - LinkedIn: https://www.linkedin.com/in/gary-johnson-0168b985/

## License

MIT
