.PHONY: lint template template-debug dry-run test clean

CHART_PATH     := charts/sk8s-gateway-appset
VALUES_FILE    := $(CHART_PATH)/values.yaml
RELEASE_NAME   := sk8s-gateway-appset
NAMESPACE      := argocd
ENVIRONMENT    ?= dev
REGION         ?= us
KUBE_CONTEXT   ?= 4054-sk8s-ops-prod

## Run all local tests (lint + template)
test: lint template

## Lint the Helm chart
lint:
	@echo "==> Linting $(CHART_PATH)..."
	helm lint $(CHART_PATH) \
		--values $(VALUES_FILE) \
		--set environment=$(ENVIRONMENT) \
		--set region=$(REGION)

## Render the ApplicationSet template
template:
	@echo "==> Rendering template..."
	helm template $(RELEASE_NAME) $(CHART_PATH) \
		--values $(VALUES_FILE) \
		--set environment=$(ENVIRONMENT) \
		--set region=$(REGION) \
		--namespace $(NAMESPACE)

## Render with debug output
template-debug:
	@echo "==> Rendering template (debug)..."
	helm template $(RELEASE_NAME) $(CHART_PATH) \
		--values $(VALUES_FILE) \
		--set environment=$(ENVIRONMENT) \
		--set region=$(REGION) \
		--namespace $(NAMESPACE) \
		--debug

## Dry-run install against a cluster (requires kubeconfig)
dry-run:
	@echo "==> Dry-run install to $(KUBE_CONTEXT)..."
	helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--values $(VALUES_FILE) \
		--set environment=$(ENVIRONMENT) \
		--set region=$(REGION) \
		--namespace $(NAMESPACE) \
		--kube-context $(KUBE_CONTEXT) \
		--dry-run

## Show generated application names only
show-apps:
	@helm template $(RELEASE_NAME) $(CHART_PATH) \
		--values $(VALUES_FILE) \
		--namespace $(NAMESPACE) 2>/dev/null \
		| grep "name: 'sk8s-gw-"

## Validate cluster config YAML
validate-config:
	@echo "==> Validating cluster config..."
	@cat environments/$(ENVIRONMENT)/$(REGION)/cluster.config.yaml | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin); print('✅ Valid YAML')" 2>/dev/null || echo "❌ Invalid YAML"

## Clean generated files
clean:
	@rm -rf $(CHART_PATH)/charts/ $(CHART_PATH)/*.tgz
