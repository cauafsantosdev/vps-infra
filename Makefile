COMPOSE := docker compose
NETWORKS := vps-edge vps-data vps-monitoring

.PHONY: help networks config up down restart pull deploy status logs health db-create backup restore install-timers

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
	@echo "  make backup                Backup application databases"
	@echo "  make restore FILE=/path/to/backup.sql.gz  Restore application databases"
	@echo "  make install-timers        Install systemd timers for backups and health checks"

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

backup:
	sudo ./scripts/backup.sh

restore:
	@test -n "$(FILE)" || (echo "usage: make restore FILE=/path/to/backup.sql.gz" && exit 1)
	sudo ./scripts/restore.sh "$(FILE)"

install-timers:
	sudo ./scripts/install-systemd.sh