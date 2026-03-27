# sk8s-platform-gitops

GitOps repository for the Standardized Kubernetes Platform (sk8s). Manages gateway deployments across multi-tenant clusters using ArgoCD ApplicationSets.

## Repository Structure

```
├── .cicd/
│   └── deploy-helm.jenkins       # Jenkins pipeline for deploying the AppSet chart
├── charts/
│   └── sk8s-gateway-appset/      # ArgoCD ApplicationSet Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           └── applicationset.yaml
├── environments/
│   └── {env}/{region}/           # e.g., dev/us, staging/eu, prod/us
│       ├── cluster.config.yaml   # Multi-tenant cluster config with asset assignments
│       ├── default-gateway.yaml  # Global gateway defaults
│       ├── global-plugins.yaml   # Global APISIX plugin config
│       └── {assetId}/            # Per-team configuration (e.g., 3363, 4054)
│           ├── apps/             # Application workloads
│           └── gateway/          # Gateway configuration
│               ├── chart.yaml    # sk8s-gateway chart version for this asset
│               └── values/       # Gateway value files
│                   └── gateway.yaml
└── Makefile                      # Test and validation targets
```

## How It Works

1. **`cluster.config.yaml`** defines multi-tenant cluster groups (stateless/stateful) with:
   - Cluster names and regions
   - Status (`active` / `full`) — `full` MT groups are excluded from deployments
   - Asset ID assignments — which teams deploy to which MT clusters
   - `hasGateway` flag — skips asset IDs that don't have gateway configurations

2. **The ApplicationSet Helm chart** reads this config and generates **one ArgoCD Application per (clusterType × assetId × cluster)** combination, deploying the `sk8s-gateway` chart with per-asset value files.

3. Each Application uses **multi-source**:
   - Git repo for value files (`default-gateway.yaml` + `{assetId}/gateway/values/`)
   - `sk8s-gateway` Helm chart from JFrog (`https://jfrog.com/lnlp-sk8s`)

## Quick Start

```bash
# Run lint + template rendering
make test

# Lint only
make lint

# Render the ApplicationSet YAML
make template

# Show generated application names
make show-apps

# Validate cluster config YAML
make validate-config

# Dry-run install (requires kubeconfig)
make dry-run

# Override environment/region
make test ENVIRONMENT=staging REGION=eu
```

## Cluster Configuration

Each asset ID entry in `cluster.config.yaml` supports:

| Field | Description |
|-------|-------------|
| `id` | The asset identifier (e.g., `"3363"`) |
| `hasGateway` | Set to `false` to skip gateway deployment for this asset |

Each MT group supports:

| Field | Description |
|-------|-------------|
| `status: active` | Accepting deployments |
| `status: full` | No new deployments — entire group is skipped |

> **Constraint**: An asset ID can appear in multiple MT groups, but only one can be `active` at a time.

## Gateway Chart Versioning

Each asset ID pins its own `sk8s-gateway` chart version in `gateway/chart.yaml`:

```yaml
repoURL: https://jfrog.com/lnlp-sk8s
chart: sk8s-gateway
targetRevision: "1.0.0"
```

## Deployment

The Jenkins pipeline (`.cicd/deploy-helm.jenkins`) deploys the AppSet chart to the `4054-sk8s-ops-prod` ArgoCD cluster. It supports:
- Environment/region parameters
- Dry-run mode (lint + template only)
- Post-deploy verification of generated Applications

## ArgoCD

- **Project**: `core-components`
- **Destination namespace**: `apisix` (configurable)
- **Sync policy**: Auto-prune, self-heal, and retry are configurable via `values.yaml`
