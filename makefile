# Makefile for Kubernetes REST API Project

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Environment variables
NAMESPACE      ?= wallet-app
APP_NAME       ?= wallet-api
DB_NAME        ?= mysql
KUBE_CONTEXT   ?= minikube

# File paths
MANIFESTS_BASE_DIR  := ./base
MANIFESTS_API_DIR   := ./apps/api
MANIFESTS_DB_DIR    := ./apps/database
SCRIPTS_DIR         := scripts

# Colors for output
GREEN          := \033[0;32m
YELLOW         := \033[0;33m
RED            := \033[0;31m
NC             := \033[0m # No Color

# ==============================================================================
# TARGETS
# ==============================================================================

.PHONY: help deploy delete clean status logs debug test port-forward setup

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

help: ## Display this help message
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  ${YELLOW}%-20s${NC} %s\n", $$1, $$2}'

# ------------------------------------------------------------------------------
# Deployment
# ------------------------------------------------------------------------------

deploy: validate ## Deploy the entire application
	@echo "${GREEN}🚀 Deploying application...${NC}"
	@echo "${YELLOW}Setting kubectl context: ${KUBE_CONTEXT}${NC}"
	kubectl config use-context $(KUBE_CONTEXT)
	
	@echo "${YELLOW}Creating base resources...${NC}"
	kubectl apply -f $(MANIFESTS_BASE_DIR)/namespace.yaml
	kubectl apply -f $(MANIFESTS_BASE_DIR)/configmap.yaml
	kubectl apply -f $(MANIFESTS_BASE_DIR)/secret.yaml
	
	@echo "${YELLOW}Deploying database...${NC}"
	kubectl apply -f $(MANIFESTS_DB_DIR)/mysql-pvc.yaml
	kubectl apply -f $(MANIFESTS_DB_DIR)/mysql-init-configmap.yaml
	kubectl apply -f $(MANIFESTS_DB_DIR)/mysql-deployment.yaml
	
	@echo "${YELLOW}Waiting for database to be ready...${NC}"
	kubectl wait --for=condition=ready pod -l app=$(DB_NAME) -n $(NAMESPACE) --timeout=300s
	
	@echo "${YELLOW}Deploying application...${NC}"
	kubectl apply -f $(MANIFESTS_API_DIR)/app-deployment.yaml
	kubectl apply -f $(MANIFESTS_API_DIR)/hpa.yaml
	kubectl apply -f ./ingress.yaml
	
	@echo "${YELLOW}Waiting for application to be ready...${NC}"
	kubectl wait --for=condition=ready pod -l app=$(APP_NAME) -n $(NAMESPACE) --timeout=180s
	
	@echo "${GREEN}✅ Deployment completed!${NC}"
	@make status

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------

delete: ## Delete all resources but keep namespace
	@echo "${YELLOW}🗑️  Deleting resources...${NC}"
	kubectl delete -f $(MANIFESTS_BASE_DIR) --ignore-not-found=true
	kubectl delete -f $(MANIFESTS_API_DIR) --ignore-not-found=true
	kubectl delete -f $(MANIFESTS_DB_DIR) --ignore-not-found=true
	kubectl delete -f ./ingress.yaml --ignore-not-found=true

clean: delete ## Complete cleanup (delete everything including namespace)
	@echo "${RED}🔥 Complete cleanup...${NC}"
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	kubectl delete pvc -n $(NAMESPACE) --all --ignore-not-found=true

# ------------------------------------------------------------------------------
# Monitoring & Debugging
# ------------------------------------------------------------------------------

status: ## Show current status
	@echo "${GREEN}📊 Current Status:${NC}"
	@echo "${YELLOW}Namespace:${NC}"
	@kubectl get namespace $(NAMESPACE) 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "${YELLOW}Pods:${NC}"
	@kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "${YELLOW}Services:${NC}"
	@kubectl get services -n $(NAMESPACE) 2>/dev/null || echo "No services found"
	@echo ""
	@echo "${YELLOW}Deployments:${NC}"
	@kubectl get deployments -n $(NAMESPACE) 2>/dev/null || echo "No deployments found"
	@echo ""
	@echo "${YELLOW}HPA:${NC}"
	@kubectl get hpa -n $(NAMESPACE) 2>/dev/null || echo "No HPA found"
	@echo ""
	@echo "${YELLOW}Ingress:${NC}"
	@kubectl get ingress -n $(NAMESPACE) 2>/dev/null || echo "No ingress found"

logs: ## Tail application logs
	@echo "${GREEN}📋 Application logs:${NC}"
	kubectl logs -n $(NAMESPACE) deployment/$(APP_NAME) -f

logs-db: ## Tail database logs
	@echo "${GREEN}📋 Database logs:${NC}"
	kubectl logs -n $(NAMESPACE) deployment/$(DB_NAME) -f

# ------------------------------------------------------------------------------
# Development
# ------------------------------------------------------------------------------

port-forward: ## Port forward to the application
	@echo "${GREEN}🔗 Port forwarding to application...${NC}"
	@echo "Application available at: http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward -n $(NAMESPACE) service/$(APP_NAME) 8080:8080

test-db-connection: ## Test database connection
	@echo "${GREEN}🧪 Testing database connection...${NC}"
	kubectl exec -n $(NAMESPACE) deployment/$(DB_NAME) -- \
		mysql -u mysql -pmypass mydb -e "SHOW DATABASES; SELECT 'Database connection successful!' AS Status;"

# ------------------------------------------------------------------------------
# Validation & Setup
# ------------------------------------------------------------------------------

validate: ## Validate Kubernetes manifests
	@echo "${GREEN}✅ Validating manifests...${NC}"
	kubectl apply --dry-run=client -f $(MANIFESTS_BASE_DIR)/
	kubectl apply --dry-run=client -f $(MANIFESTS_API_DIR)/
	kubectl apply --dry-run=client -f $(MANIFESTS_DB_DIR)/
	kubectl apply --dry-run=client -f ./ingress.yaml
	@echo "${GREEN}✅ All manifests are valid!${NC}"

# ------------------------------------------------------------------------------
# Simple Commands
# ------------------------------------------------------------------------------

deploy-quick: ## Quick deploy without validation
	kubectl apply -f $(MANIFESTS_BASE_DIR)/
	kubectl apply -f $(MANIFESTS_DB_DIR)/
	sleep 10
	kubectl apply -f $(MANIFESTS_API_DIR)/
	kubectl apply -f ./ingress.yaml

restart: ## Restart the application
	@echo "${GREEN}🔄 Restarting application...${NC}"
	kubectl rollout restart deployment/$(APP_NAME) -n $(NAMESPACE)

tree: ## Show project structure
	@echo "${GREEN}📁 Project Structure:${NC}"
	@find . -type f -name "*.yaml" -o -name "*.yml" | grep -v node_modules | sort | sed 's|^\./||'