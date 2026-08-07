# =============================================================================
# Cloud Observability Platform - Makefile
# One command to deploy everything. One command to destroy everything.
# =============================================================================

.PHONY: help up down cluster apps obs status clean port-forward

# Default: show help
help:
	@echo "Available commands:"
	@echo "  make up          - Deploy cluster + apps + observability"
	@echo "  make down        - Destroy everything (cluster + apps)"
	@echo "  make cluster     - Deploy kind cluster via Terraform"
	@echo "  make apps        - Deploy Online Boutique app"
	@echo "  make obs         - Deploy observability stack (Grafana, Prometheus, etc.)"
	@echo "  make status      - Check status of all pods"
	@echo "  make port-forward - Forward Grafana port to localhost:3000"
	@echo "  make clean       - Remove generated files"

# =============================================================================
# FULL DEPLOY
# =============================================================================

up: cluster apps
	@echo "========================================"
	@echo "  Platform deployed successfully!"
	@echo "  App: http://localhost"
	@echo "  Grafana: http://localhost:3000 (after 'make obs')"
	@echo "========================================"

# =============================================================================
# CLUSTER (Terraform)
# =============================================================================

cluster:
	@echo ">>> Creating kind cluster..."
	cd terraform && terraform init
	cd terraform && terraform apply -auto-approve
	@echo ">>> Cluster ready. Setting kubectl context..."
	kubectl cluster-info

# =============================================================================
# APPLICATIONS (Online Boutique)
# =============================================================================

apps:
	@echo ">>> Deploying Online Boutique..."
	kubectl apply -k apps/online-boutique/ -n apps
	kubectl apply -f apps/online-boutique/ingress.yaml -n apps
	@echo ">>> Waiting for app pods..."
	sleep 10
	kubectl get pods -n apps
	@echo ">>> App should be available at http://localhost"

# =============================================================================
# OBSERVABILITY STACK (Phase 6+)
# =============================================================================

obs:
	@echo ">>> Deploying observability stack..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
	helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
	helm repo update
	helm install prometheus prometheus-community/prometheus \
		-n observability -f helm/observability/prometheus-values.yaml 2>/dev/null || echo "Prometheus already installed or error"
	helm install grafana grafana/grafana \
		-n observability -f helm/observability/grafana-values.yaml 2>/dev/null || echo "Grafana already installed or error"
	@echo ">>> Waiting for observability pods..."
	sleep 15
	kubectl get pods -n observability
	@echo ">>> Grafana available at http://localhost:3000 (run 'make port-forward' to access)"

# =============================================================================
# STATUS CHECKS
# =============================================================================

status:
	@echo ">>> Nodes:"
	@kubectl get nodes
	@echo ""
	@echo ">>> App Pods:"
	@kubectl get pods -n apps
	@echo ""
	@echo ">>> Observability Pods:"
	@kubectl get pods -n observability 2>/dev/null || echo "    (No observability pods yet - run 'make obs')"

# =============================================================================
# PORT FORWARDING
# =============================================================================

port-forward:
	@echo ">>> Forwarding Grafana to http://localhost:3000"
	@echo "    Press Ctrl+C to stop"
	kubectl port-forward -n observability svc/grafana 3000:80

# =============================================================================
# DESTROY EVERYTHING
# =============================================================================

down:
	@echo ">>> Destroying cluster..."
	cd terraform && terraform destroy -auto-approve
	@echo ">>> Cleanup complete."

# =============================================================================
# CLEAN GENERATED FILES
# =============================================================================

clean:
	@echo ">>> Removing generated files..."
	rm -rf terraform/.terraform terraform/terraform.tfstate terraform/terraform.tfstate.backup
	rm -rf apps/online-boutique/base.yaml
	@echo ">>> Cleaned."
