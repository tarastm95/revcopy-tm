# ==============================================================================
# RevCopy Server Deployment Makefile
# Enterprise-grade deployment automation and management
# ==============================================================================

# Variables
PROJECT_NAME := revcopy
DOCKER_COMPOSE := docker-compose
DOCKER_COMPOSE_FILE := docker-compose.yml
ENV_FILE := .env
SERVER_HOST ?= 37.27.217.240

# CLI and deployment paths
CLI_SCRIPT := ./revcopy-cli.py
INSTALL_SCRIPT := ./install.sh
REQUIREMENTS_CLI := requirements-cli.txt

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# ==============================================================================
# HELP
# ==============================================================================
.PHONY: help
help: ## Display this help message
	@echo "$(BLUE)RevCopy Server Management Commands$(NC)"
	@echo "=================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================
.PHONY: init
init: ## Initialize the project (first-time setup)
	@echo "$(BLUE)Initializing RevCopy Server...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)Creating .env file from template...$(NC)"; \
		cp env-template.txt .env; \
		echo "$(RED)Please configure your .env file before proceeding!$(NC)"; \
	else \
		echo "$(GREEN).env file already exists$(NC)"; \
	fi
	@chmod +x scripts/*.sh
	@echo "$(GREEN)Initialization complete!$(NC)"

.PHONY: env-check
env-check: ## Check environment configuration
	@echo "$(BLUE)Checking environment configuration...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(RED)Error: .env file not found! Run 'make init' first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Environment configuration found$(NC)"

.PHONY: secrets
secrets: ## Generate secure secrets for the environment
	@echo "$(BLUE)Generating secure secrets...$(NC)"
	@./scripts/generate-secrets.sh
	@echo "$(GREEN)Secrets generated! Check your .env file.$(NC)"

# ==============================================================================
# DEVELOPMENT
# ==============================================================================
.PHONY: dev
dev: env-check ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up --build frontend admin backend amazon-crawler postgres redis

.PHONY: dev-logs
dev-logs: ## View development logs
	@$(DOCKER_COMPOSE) logs -f frontend admin backend amazon-crawler

.PHONY: dev-down
dev-down: ## Stop development environment
	@echo "$(YELLOW)Stopping development environment...$(NC)"
	@$(DOCKER_COMPOSE) down

# ==============================================================================
# PRODUCTION DEPLOYMENT
# ==============================================================================
.PHONY: deploy-production
deploy-production: env-check build ## Deploy full production stack
	@echo "$(BLUE)Deploying production environment...$(NC)"
	@$(DOCKER_COMPOSE) -f $(DOCKER_COMPOSE_FILE) up -d
	@sleep 10
	@make health-check
	@echo "$(GREEN)Production deployment complete!$(NC)"

.PHONY: deploy-staging
deploy-staging: env-check ## Deploy staging environment
	@echo "$(BLUE)Deploying staging environment...$(NC)"
	@ENVIRONMENT=staging $(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)Staging deployment complete!$(NC)"

.PHONY: deploy-development
deploy-development: env-check ## Deploy development environment
	@echo "$(BLUE)Deploying development environment...$(NC)"
	@ENVIRONMENT=development $(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)Development deployment complete!$(NC)"

# ==============================================================================
# BUILD OPERATIONS
# ==============================================================================
.PHONY: build
build: ## Build all Docker images
	@echo "$(BLUE)Building all Docker images...$(NC)"
	@$(DOCKER_COMPOSE) build --no-cache

.PHONY: build-backend
build-backend: ## Build backend image
	@$(DOCKER_COMPOSE) build --no-cache backend

.PHONY: build-frontend
build-frontend: ## Build frontend image
	@$(DOCKER_COMPOSE) build --no-cache frontend

.PHONY: build-admin
build-admin: ## Build admin image
	@$(DOCKER_COMPOSE) build --no-cache admin

.PHONY: build-crawler
build-crawler: ## Build crawler image
	@$(DOCKER_COMPOSE) build --no-cache amazon-crawler

# ==============================================================================
# SERVICE MANAGEMENT
# ==============================================================================
.PHONY: start
start: ## Start all services
	@echo "$(BLUE)Starting all services...$(NC)"
	@$(DOCKER_COMPOSE) start

.PHONY: stop
stop: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@$(DOCKER_COMPOSE) stop

.PHONY: restart
restart: stop start ## Restart all services

.PHONY: down
down: ## Stop and remove all containers
	@echo "$(YELLOW)Stopping and removing containers...$(NC)"
	@$(DOCKER_COMPOSE) down -v

.PHONY: ps
ps: ## Show running containers
	@$(DOCKER_COMPOSE) ps

# ==============================================================================
# SCALING
# ==============================================================================
.PHONY: scale-backend
scale-backend: ## Scale backend service (usage: make scale-backend REPLICAS=3)
	@$(DOCKER_COMPOSE) up -d --scale backend=$(or $(REPLICAS),2)

.PHONY: scale-crawler
scale-crawler: ## Scale crawler service (usage: make scale-crawler REPLICAS=3)
	@$(DOCKER_COMPOSE) up -d --scale amazon-crawler=$(or $(REPLICAS),2)

# ==============================================================================
# MONITORING & LOGS
# ==============================================================================
.PHONY: logs
logs: ## View all logs
	@$(DOCKER_COMPOSE) logs -f

.PHONY: logs-backend
logs-backend: ## View backend logs
	@$(DOCKER_COMPOSE) logs -f backend

.PHONY: logs-frontend
logs-frontend: ## View frontend logs
	@$(DOCKER_COMPOSE) logs -f frontend

.PHONY: logs-admin
logs-admin: ## View admin logs
	@$(DOCKER_COMPOSE) logs -f admin

.PHONY: logs-database
logs-database: ## View database logs
	@$(DOCKER_COMPOSE) logs -f postgres

.PHONY: logs-errors
logs-errors: ## View error logs only
	@$(DOCKER_COMPOSE) logs -f | grep -i error

.PHONY: status
status: ## Show service status
	@echo "$(BLUE)Service Status:$(NC)"
	@$(DOCKER_COMPOSE) ps
	@echo "\n$(BLUE)Resource Usage:$(NC)"
	@docker stats --no-stream

.PHONY: health-check
health-check: ## Perform health checks on all services
	@echo "$(BLUE)Performing health checks...$(NC)"
	@./scripts/health-check.sh

# ==============================================================================
# DATABASE OPERATIONS
# ==============================================================================
.PHONY: db-migrate
db-migrate: ## Run database migrations
	@echo "$(BLUE)Running database migrations...$(NC)"
	@$(DOCKER_COMPOSE) exec backend alembic upgrade head

.PHONY: db-backup
db-backup: ## Backup database
	@echo "$(BLUE)Creating database backup...$(NC)"
	@./scripts/backup-database.sh

.PHONY: db-restore
db-restore: ## Restore database (usage: make db-restore BACKUP_FILE=backup.sql)
	@echo "$(BLUE)Restoring database...$(NC)"
	@./scripts/restore-database.sh $(BACKUP_FILE)

.PHONY: db-shell
db-shell: ## Access database shell
	@$(DOCKER_COMPOSE) exec postgres psql -U $(shell grep POSTGRES_USER .env | cut -d '=' -f2) -d $(shell grep POSTGRES_DB .env | cut -d '=' -f2)

# ==============================================================================
# MAINTENANCE
# ==============================================================================
.PHONY: clean
clean: ## Clean up unused Docker resources
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker system prune -f
	@docker volume prune -f
	@docker image prune -f

.PHONY: clean-all
clean-all: ## Clean up all Docker resources (including volumes)
	@echo "$(RED)Warning: This will remove ALL Docker data!$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@docker system prune -a -f --volumes

.PHONY: update-images
update-images: ## Update all Docker images
	@echo "$(BLUE)Updating Docker images...$(NC)"
	@$(DOCKER_COMPOSE) pull

.PHONY: rolling-update
rolling-update: ## Perform rolling update
	@echo "$(BLUE)Performing rolling update...$(NC)"
	@./scripts/rolling-update.sh

# ==============================================================================
# SECURITY & MAINTENANCE
# ==============================================================================
.PHONY: security-scan
security-scan: ## Run security scan on images
	@echo "$(BLUE)Running security scan...$(NC)"
	@./scripts/security-scan.sh

.PHONY: ssl-setup
ssl-setup: ## Setup SSL certificates
	@echo "$(BLUE)Setting up SSL certificates...$(NC)"
	@./scripts/setup-ssl.sh

.PHONY: ssl-renew
ssl-renew: ## Renew SSL certificates
	@echo "$(BLUE)Renewing SSL certificates...$(NC)"
	@$(DOCKER_COMPOSE) exec certbot certbot renew

# ==============================================================================
# TESTING
# ==============================================================================
.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	@$(DOCKER_COMPOSE) exec backend pytest
	@$(DOCKER_COMPOSE) exec amazon-crawler go test ./...

.PHONY: test-backend
test-backend: ## Run backend tests
	@$(DOCKER_COMPOSE) exec backend pytest -v

.PHONY: test-crawler
test-crawler: ## Run crawler tests
	@$(DOCKER_COMPOSE) exec amazon-crawler go test -v ./...

.PHONY: performance-test
performance-test: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(NC)"
	@./scripts/performance-test.sh

# ==============================================================================
# UTILITIES
# ==============================================================================
.PHONY: shell
shell: ## Access backend container shell
	@$(DOCKER_COMPOSE) exec backend /bin/bash

.PHONY: shell-crawler
shell-crawler: ## Access crawler container shell
	@$(DOCKER_COMPOSE) exec amazon-crawler /bin/sh

.PHONY: network-test
network-test: ## Test network connectivity
	@echo "$(BLUE)Testing network connectivity...$(NC)"
	@./scripts/network-test.sh

.PHONY: resources
resources: ## Show resource usage
	@docker stats --no-stream

# ==============================================================================
# BACKUP & RESTORE
# ==============================================================================
.PHONY: backup-all
backup-all: ## Backup everything (database, volumes, configs)
	@echo "$(BLUE)Creating full backup...$(NC)"
	@./scripts/backup-all.sh

.PHONY: restore-production
restore-production: ## Restore production from backup
	@echo "$(BLUE)Restoring production from backup...$(NC)"
	@./scripts/restore-production.sh $(BACKUP_DATE)

# ==============================================================================
# CONFIGURATION
# ==============================================================================
.PHONY: config-validate
config-validate: ## Validate configuration files
	@echo "$(BLUE)Validating configuration...$(NC)"
	@$(DOCKER_COMPOSE) config

.PHONY: config-show
config-show: ## Show merged configuration
	@$(DOCKER_COMPOSE) config

# ==============================================================================
# QUICKSTART TARGETS
# ==============================================================================
.PHONY: quickstart
quickstart: init secrets deploy-development ## Quick setup for development

.PHONY: production-deploy
production-deploy: env-check build deploy-production ## Full production deployment

# ==============================================================================
# EMERGENCY PROCEDURES
# ==============================================================================
.PHONY: emergency-stop
emergency-stop: ## Emergency stop all services
	@echo "$(RED)EMERGENCY STOP - Stopping all services immediately$(NC)"
	@$(DOCKER_COMPOSE) kill
	@$(DOCKER_COMPOSE) down

.PHONY: emergency-restart
emergency-restart: emergency-stop start ## Emergency restart

# ==============================================================================
# VERSION INFO
# ==============================================================================
.PHONY: version
version: ## Show version information
	@echo "$(BLUE)RevCopy Server Version Information$(NC)"
	@echo "=================================="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Docker Compose Version: $(shell $(DOCKER_COMPOSE) --version)"
	@echo "Docker Version: $(shell docker --version)"
	@echo "Make Version: $(shell make --version | head -1)"

# ==============================================================================
# CLI DEPLOYMENT AUTOMATION
# ==============================================================================
.PHONY: install-cli
install-cli: ## Install CLI dependencies
	@echo "$(BLUE)Installing CLI dependencies...$(NC)"
	@pip3 install -r $(REQUIREMENTS_CLI)
	@chmod +x $(CLI_SCRIPT)
	@echo "$(GREEN)CLI dependencies installed successfully$(NC)"

.PHONY: server-setup
server-setup: ## Setup remote server (requires SERVER_HOST)
	@echo "$(BLUE)Setting up server $(SERVER_HOST)...$(NC)"
	@if [ -z "$(SERVER_HOST)" ]; then \
		echo "$(RED)Error: SERVER_HOST not specified!$(NC)"; \
		echo "Usage: make server-setup SERVER_HOST=your.server.ip"; \
		exit 1; \
	fi
	@ssh -o StrictHostKeyChecking=no root@$(SERVER_HOST) 'bash -s' < $(INSTALL_SCRIPT)
	@echo "$(GREEN)Server setup completed$(NC)"

.PHONY: deploy-remote
deploy-remote: ## Deploy to remote server using CLI
	@echo "$(BLUE)Deploying to remote server $(SERVER_HOST)...$(NC)"
	@python3 $(CLI_SCRIPT) deploy --server $(SERVER_HOST) --full --ssl --monitoring
	@echo "$(GREEN)Remote deployment completed$(NC)"

.PHONY: deploy-update
deploy-update: ## Update deployment on remote server
	@echo "$(BLUE)Updating deployment on $(SERVER_HOST)...$(NC)"
	@python3 $(CLI_SCRIPT) deploy --server $(SERVER_HOST)
	@echo "$(GREEN)Deployment updated$(NC)"

.PHONY: server-cleanup
server-cleanup: ## Clean up remote server
	@echo "$(YELLOW)Cleaning up server $(SERVER_HOST)...$(NC)"
	@python3 $(CLI_SCRIPT) cleanup --server $(SERVER_HOST)
	@echo "$(GREEN)Server cleanup completed$(NC)"

.PHONY: server-health
server-health: ## Check remote server health
	@echo "$(BLUE)Checking server health $(SERVER_HOST)...$(NC)"
	@python3 $(CLI_SCRIPT) health --server $(SERVER_HOST)

# ==============================================================================
# GITOPS & AUTOMATION
# ==============================================================================
.PHONY: setup-webhook
setup-webhook: ## Setup webhook handler on server
	@echo "$(BLUE)Setting up webhook handler...$(NC)"
	@ssh root@$(SERVER_HOST) 'systemctl enable revcopy-webhook && systemctl start revcopy-webhook'
	@echo "$(GREEN)Webhook handler setup completed$(NC)"
	@echo "$(YELLOW)Configure GitHub webhooks to point to: http://$(SERVER_HOST):8080/webhook$(NC)"

.PHONY: webhook-status
webhook-status: ## Check webhook handler status
	@ssh root@$(SERVER_HOST) 'systemctl status revcopy-webhook'

.PHONY: setup-ci
setup-ci: ## Setup CI/CD pipeline
	@echo "$(BLUE)Setting up CI/CD pipeline...$(NC)"
	@echo "$(GREEN)GitHub Actions workflow is already configured$(NC)"
	@echo "$(YELLOW)Make sure to set these secrets in your GitHub repository:$(NC)"
	@echo "  - SERVER_SSH_KEY: Your SSH private key"
	@echo "  - SLACK_WEBHOOK: Slack webhook URL (optional)"

# ==============================================================================
# MONITORING & OBSERVABILITY
# ==============================================================================
.PHONY: monitoring-setup
monitoring-setup: ## Setup monitoring stack
	@echo "$(BLUE)Setting up monitoring...$(NC)"
	@$(DOCKER_COMPOSE) up -d prometheus grafana node-exporter
	@sleep 10
	@echo "$(GREEN)Monitoring stack started$(NC)"
	@echo "$(BLUE)Prometheus: http://$(SERVER_HOST):9090$(NC)"
	@echo "$(BLUE)Grafana: http://$(SERVER_HOST):3000$(NC)"

.PHONY: monitoring-down
monitoring-down: ## Stop monitoring stack
	@$(DOCKER_COMPOSE) stop prometheus grafana node-exporter

.PHONY: logs-monitoring
logs-monitoring: ## View monitoring logs
	@$(DOCKER_COMPOSE) logs -f prometheus grafana

# ==============================================================================
# SECURITY OPERATIONS
# ==============================================================================
.PHONY: security-setup
security-setup: ## Setup security measures
	@echo "$(BLUE)Setting up security measures...$(NC)"
	@ssh root@$(SERVER_HOST) 'ufw status && fail2ban-client status'
	@echo "$(GREEN)Security status checked$(NC)"

.PHONY: ssl-check
ssl-check: ## Check SSL certificate status
	@echo "$(BLUE)Checking SSL certificate...$(NC)"
	@openssl s_client -connect $(SERVER_HOST):443 -servername $(SERVER_HOST) < /dev/null 2>/dev/null | openssl x509 -noout -dates

.PHONY: backup-remote
backup-remote: ## Create backup on remote server
	@echo "$(BLUE)Creating backup on $(SERVER_HOST)...$(NC)"
	@ssh root@$(SERVER_HOST) 'cd /opt/revcopy/revcopy-server && make backup-all'
	@echo "$(GREEN)Backup completed$(NC)"

# ==============================================================================
# DEVELOPMENT HELPERS
# ==============================================================================
.PHONY: dev-tunnel
dev-tunnel: ## Create SSH tunnel for development
	@echo "$(BLUE)Creating SSH tunnel to $(SERVER_HOST)...$(NC)"
	@ssh -L 8000:localhost:8000 -L 5173:localhost:5173 -L 3001:localhost:3001 -L 9000:localhost:9000 root@$(SERVER_HOST)

.PHONY: sync-env
sync-env: ## Sync environment file to server
	@echo "$(BLUE)Syncing environment file to server...$(NC)"
	@scp .env.production root@$(SERVER_HOST):/opt/revcopy/revcopy-server/.env
	@echo "$(GREEN)Environment file synced$(NC)"

.PHONY: debug-remote
debug-remote: ## Debug remote deployment
	@echo "$(BLUE)Debugging remote deployment...$(NC)"
	@ssh root@$(SERVER_HOST) 'cd /opt/revcopy/revcopy-server && docker-compose ps && docker-compose logs --tail=50'

# ==============================================================================
# PERFORMANCE & OPTIMIZATION
# ==============================================================================
.PHONY: performance-monitor
performance-monitor: ## Monitor performance metrics
	@echo "$(BLUE)Monitoring performance...$(NC)"
	@ssh root@$(SERVER_HOST) 'htop -d 1'

.PHONY: optimize-server
optimize-server: ## Optimize server performance
	@echo "$(BLUE)Optimizing server performance...$(NC)"
	@ssh root@$(SERVER_HOST) 'docker system prune -f && sync && echo 3 > /proc/sys/vm/drop_caches'
	@echo "$(GREEN)Server optimization completed$(NC)"

# ==============================================================================
# DISASTER RECOVERY
# ==============================================================================
.PHONY: disaster-recovery
disaster-recovery: ## Run disaster recovery procedure
	@echo "$(RED)Starting disaster recovery procedure...$(NC)"
	@echo "$(YELLOW)This will restore the latest backup$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@ssh root@$(SERVER_HOST) 'cd /opt/revcopy/revcopy-server && make restore-production'

.PHONY: emergency-deploy
emergency-deploy: ## Emergency deployment (bypass checks)
	@echo "$(RED)Emergency deployment to $(SERVER_HOST)...$(NC)"
	@python3 $(CLI_SCRIPT) deploy --server $(SERVER_HOST) --full
	@echo "$(GREEN)Emergency deployment completed$(NC)"

# ==============================================================================
# COMPREHENSIVE WORKFLOWS
# ==============================================================================
.PHONY: full-setup
full-setup: install-cli server-setup deploy-remote setup-webhook monitoring-setup ## Complete server setup and deployment
	@echo "$(GREEN)Full setup completed successfully!$(NC)"
	@echo "$(BLUE)Your RevCopy server is ready at: https://$(SERVER_HOST)$(NC)"

.PHONY: quick-deploy
quick-deploy: deploy-update server-health ## Quick deployment and health check

.PHONY: production-ready
production-ready: full-setup ssl-check security-setup ## Full production-ready deployment

# ==============================================================================
# TROUBLESHOOTING
# ==============================================================================
.PHONY: troubleshoot
troubleshoot: ## Run troubleshooting diagnostics
	@echo "$(BLUE)Running troubleshooting diagnostics...$(NC)"
	@echo "$(YELLOW)Local Environment:$(NC)"
	@python3 --version || echo "Python3 not found"
	@docker --version || echo "Docker not found"
	@docker-compose --version || echo "Docker Compose not found"
	@echo "$(YELLOW)Remote Server ($(SERVER_HOST)):$(NC)"
	@ssh root@$(SERVER_HOST) 'python3 --version && docker --version && systemctl status docker'
	@echo "$(YELLOW)Service Status:$(NC)"
	@python3 $(CLI_SCRIPT) health --server $(SERVER_HOST) || echo "Health check failed"

.PHONY: fix-permissions
fix-permissions: ## Fix file permissions
	@echo "$(BLUE)Fixing file permissions...$(NC)"
	@chmod +x $(CLI_SCRIPT) $(INSTALL_SCRIPT) scripts/*.sh
	@ssh root@$(SERVER_HOST) 'chmod +x /opt/revcopy/revcopy-server/revcopy-cli.py /opt/revcopy/revcopy-server/scripts/*.sh'

# ==============================================================================
# INFORMATION TARGETS
# ==============================================================================
.PHONY: info
info: ## Show deployment information
	@echo "$(BLUE)RevCopy Deployment Information$(NC)"
	@echo "================================"
	@echo "Server Host: $(SERVER_HOST)"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Git Branch: $(shell git branch --show-current 2>/dev/null || echo 'unknown')"
	@echo "Git Commit: $(shell git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
	@echo ""
	@echo "$(BLUE)Application URLs:$(NC)"
	@echo "Frontend:    https://$(SERVER_HOST)/"
	@echo "Admin:       https://$(SERVER_HOST)/admin"
	@echo "API:         https://$(SERVER_HOST)/api"
	@echo "Crawler:     https://$(SERVER_HOST)/crawler"
	@echo "Webhook:     http://$(SERVER_HOST):8080/webhook"
	@echo "Prometheus:  http://$(SERVER_HOST):9090"
	@echo "Grafana:     http://$(SERVER_HOST):3000"

.PHONY: status-all
status-all: info server-health ## Show complete status

# ==============================================================================
# NOTES
# ==============================================================================
# Professional RevCopy Deployment Guide:
# 
# 1. INITIAL SETUP:
#    make full-setup SERVER_HOST=your.server.ip
# 
# 2. DEVELOPMENT:
#    make quickstart                    # Local development
#    make dev-tunnel SERVER_HOST=...    # Debug remote server
# 
# 3. PRODUCTION:
#    make production-ready SERVER_HOST=your.server.ip
# 
# 4. MAINTENANCE:
#    make quick-deploy SERVER_HOST=...  # Update deployment
#    make backup-remote SERVER_HOST=... # Create backup
#    make troubleshoot SERVER_HOST=...  # Diagnose issues
# 
# 5. MONITORING:
#    make monitoring-setup              # Start monitoring
#    make performance-monitor           # Check performance
# 
# 6. EMERGENCY:
#    make emergency-deploy SERVER_HOST=... # Emergency deployment
#    make disaster-recovery SERVER_HOST=... # Restore from backup
# 
# Environment Variables:
#   SERVER_HOST    - Target server IP/hostname
#   REPLICAS       - Number of service replicas for scaling
#   BACKUP_FILE    - Backup file for restoration
# 
# Requirements:
#   - Python 3.11+
#   - Docker & Docker Compose
#   - SSH access to target server
#   - Configured .env file
# ============================================================================== 