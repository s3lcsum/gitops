.PHONY: help drift-enforce sync-vars

help:
	@echo "Targets:"
	@echo "  drift-enforce  Upsert drift-enforce template, OnCall global var, staggered schedules"
	@echo "                 Requires GRAFANA_ONCALL_WEBHOOK_URL in the environment."
	@echo "  sync-vars      Sync Servers/terrakube-tofu → Terrakube workspace vars"

drift-enforce: ## Apply Terrakube drift-enforce template + schedules
	@test -n "$(GRAFANA_ONCALL_WEBHOOK_URL)" || (echo "Set GRAFANA_ONCALL_WEBHOOK_URL first" >&2; exit 1)
	./apply-drift-enforce.sh

sync-vars: ## Sync 1Password terrakube-tofu into Terrakube
	./sync-vars-from-1password.sh
