COMPOSE := docker compose
NETWORKS := vps-edge vps-data vps-monitoring

.PHONY: help networks config up down restart pull deploy status logs health db-create

help:
	@echo "vps-infra"
	@echo ""
	@echo "  make networks              Create shared Docker networks"
	@echo "  make config                Validate Docker Compose configuration"
	@echo "  make up                    Start shared infrastructure"
	@echo "  make down                  Stop shared infrastructure"
	@echo "  make restart               Restart shared infrastructure"
	@echo "  make pull                  Pull infrastructure images"
	@echo "  make deploy                Reconcile shared infrastructure"
	@echo "  make status                Show container status"
	@echo "  make logs                  Follow container logs"
	@echo "  make health                Run infrastructure health checks"
	@echo "  make db-create NAME=lexos  Create application database"

networks:
	@for network in $(NETWORKS); do \
		docker network inspect $$network >/dev/null 2>&1 || docker network create $$network; \
	done

config:
	$(COMPOSE) config

up: networks
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

pull:
	$(COMPOSE) pull

deploy: networks
	./scripts/deploy.sh

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

health:
	./scripts/health.sh

db-create:
	@test -n "$(NAME)" || (echo "usage: make db-create NAME=project_name" && exit 1)
	./scripts/create-database.sh "$(NAME)"