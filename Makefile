# =============================================================================
# Cloud Observability Platform - Makefile
# =============================================================================

.PHONY: help up down cluster apps obs status clean port-forward

help:
	@echo "Available commands:"
	@echo "  make cluster     - Deploy kind cluster via Terraform"
	@echo "  make apps        - Deploy Online Boutique app"
	@echo "  make obs         - Deploy observability stack"
	@echo "  make status      - Check status of all pods"
	@echo "  make port-forward - Forward Grafana to localhost:3000"
	@echo "  make down        - Destroy everything"
	@echo "  make clean       - Remove generated files"

# =============================================================================
# FULL DEPLOY (run these in order on fresh start)
# =============================================================================

cluster:
	@echo ">>> Creating kind cluster..."
	cd terraform && terraform init
	cd terraform && terraform apply -auto-approve
	@echo ">>> Cluster ready."

apps:
	@echo ">>> Deploying Online Boutique..."
	kubectl apply -k apps/online-boutique/
	kubectl apply -f apps/online-boutique/ingress.yaml -n apps
	@echo ">>> Waiting for app pods..."
	sleep 15
	kubectl get pods -n apps

obs:
	@echo ">>> Adding Helm repos..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
	helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
	helm repo update
	
	@echo ">>> Installing Prometheus..."
	helm install prometheus prometheus-community/prometheus \
		-n observability -f helm/observability/prometheus-values.yaml 2>/dev/null || echo "Prometheus already installed"
	
	@echo ">>> Installing Grafana..."
	helm install grafana grafana/grafana \
		-n observability -f helm/observability/grafana-values.yaml 2>/dev/null || echo "Grafana already installed"
	
	@echo ">>> Installing Tempo..."
	helm install tempo grafana/tempo -n observability \
		--set tempo.storage.trace.backend=local \
		--set resources.limits.memory=512Mi 2>/dev/null || echo "Tempo already installed"
	
	@echo ">>> Installing Loki..."
	helm install loki grafana/loki -n observability \
		--set deploymentMode=SingleBinary \
		--set loki.auth.enabled=false \
		--set singleBinary.replicas=1 \
		--set singleBinary.persistence.enabled=true \
		--set singleBinary.persistence.size=1Gi \
		--set backend.replicas=0 \
		--set read.replicas=0 \
		--set write.replicas=0 \
		--set test.enabled=false \
		--set monitoring.selfMonitoring.grafanaAgent.installOperator=false \
		--set resources.limits.memory=512Mi \
		--set loki.storage.type=filesystem \
		--set loki.storage.bucketNames.chunks=chunks \
		--set loki.storage.bucketNames.ruler=ruler \
		--set loki.storage.bucketNames.admin=admin \
		--set loki.useTestSchema=true 2>/dev/null || echo "Loki already installed"
	
	@echo ">>> Installing OpenTelemetry Operator..."
	helm install opentelemetry-operator open-telemetry/opentelemetry-operator \
		-n observability \
		--set manager.collectorImage.repository=otel/opentelemetry-collector-contrib \
		--set admissionWebhooks.certManager.enabled=false \
		--set admissionWebhooks.autoGenerateCert.enabled=true 2>/dev/null || echo "OTel Operator already installed"
	
	@echo ">>> Applying OTel resources..."
	kubectl apply -f helm/observability/instrumentation.yaml
	kubectl apply -f helm/observability/otel-collector.yaml
	
	@echo ">>> Waiting for observability pods..."
	sleep 20
	kubectl get pods -n observability

status:
	@echo ">>> Nodes:"
	@kubectl get nodes
	@echo ""
	@echo ">>> App Pods:"
	@kubectl get pods -n apps
	@echo ""
	@echo ">>> Observability Pods:"
	@kubectl get pods -n observability

port-forward:
	@echo ">>> Forwarding Grafana to http://localhost:3000"
	@echo "    Press Ctrl+C to stop"
	kubectl port-forward -n observability svc/grafana 3000:80

down:
	@echo ">>> Destroying cluster..."
	cd terraform && terraform destroy -auto-approve

clean:
	rm -rf terraform/.terraform terraform/*.tfstate terraform/*.tfstate.backup
