SHELL := /bin/bash
.DEFAULT_GOAL := help

help: ## Mostra i comandi
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Avvia stack docker (sviluppo)
	docker compose -f infra/docker-compose.yml up -d --build

down: ## Ferma e rimuove lo stack docker
	docker compose -f infra/docker-compose.yml down -v

logs: ## Segui i log
	docker compose -f infra/docker-compose.yml logs -f --tail=200

fmt: ## Lint/format (mobile+server+admin)
	@echo "TODO: integrare dart format, black, eslint"

dev-run: ## Avvia app Flutter con cleanup automatico token
	@echo "🚀 === AVVIO SVILUPPO CON CLEANUP AUTOMATICO ==="
	@echo "🧹 Pulizia token scaduti..."
	@python3 scripts/auto_cleanup_tokens.py
	@echo ""
	@echo "📱 Avvio app Flutter..."
	@cd mobile/securevox_app && flutter run

dev-clean: ## Cleanup manuale token sviluppo
	@echo "🧹 === CLEANUP MANUALE SVILUPPO ==="
	@python3 scripts/auto_cleanup_tokens.py

dev-server: ## Avvia solo server Django
	@echo "🚀 === AVVIO SERVER DJANGO ==="
	@cd server && python3 manage.py runserver 127.0.0.1:8000
