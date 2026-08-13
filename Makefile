COMPOSE := docker compose
NETWORKS := vps-edge vps-data

.PHONY: help networks config up down restart pull deploy status logs

help:
	@echo "vps-infra"
	@echo ""
	@echo "  make networks  Create shared Docker networks"
	@echo "  make config    Validate Docker Compose configuration"
	@echo "  make up        Start shared infrastructure"
	@echo "  make down      Stop shared infrastructure"
	@echo "  make restart   Restart shared infrastructure"
	@echo "  make pull      Pull infrastructure images"
	@echo "  make deploy    Pull and reconcile infrastructure"
	@echo "  make status    Show container status"
	@echo "  make logs      Follow container logs"

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

deploy: networks pull
	$(COMPOSE) up -d --remove-orphans

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f