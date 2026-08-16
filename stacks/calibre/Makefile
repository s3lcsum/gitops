#!/usr/bin/env make -f

# Calibre stack automation — seed CWA/GUI config from git, install GUI plugins.
# Runs against the homelab host over ssh (repo convention: ssh portainer).
# No .sh scripts: helpers are python, targets are make.

GIT_ROOT     := $(shell git rev-parse --show-toplevel)
CALIBRE_DIR  := $(GIT_ROOT)/stacks/calibre
HOST         := portainer
HOST_BASE    := /opt/calibre
GUI_IMAGE    := linuxserver/calibre:9.13.0
GUI_VOL      := calibre_calibre_config
GUI_HOME     := /config
CWA_VOL      := calibre_cwa_config
CWA_IMAGE    := crocodilestick/calibre-web-automated:v4.0.6
GITIGNORE_SEEDS := seeds/dedrm/DeDRM.zip

.PHONY: calibre-seed calibre-plugins calibre-restore calibre-sync calibre-check

calibre-restore: calibre-seed calibre-plugins ## Full restore: seed config + install plugins

calibre-sync: ## rsync seeds + plugins to host staging dir
	rsync -av --delete "$(CALIBRE_DIR)/seeds/" "$(HOST):$(HOST_BASE)/seeds/"
	rsync -av --delete "$(CALIBRE_DIR)/plugins/" "$(HOST):$(HOST_BASE)/plugins/"
	scp "$(CALIBRE_DIR)/Makefile.settings-apply.py" "$(HOST):$(HOST_BASE)/settings-apply.py"

calibre-seed: calibre-sync ## Apply GUI global.py.json, CWA DB settings, DeDRM seed; restart both
	@echo "== stop CWA (deterministic settings apply) =="
	ssh "$(HOST)" "docker stop calibre-web-automated || true"
	@echo "== apply cwa_settings =="
	ssh "$(HOST)" "docker run --rm --entrypoint python3 -v $(CWA_VOL):/config -v $(HOST_BASE):/seed:ro $(CWA_IMAGE) /seed/settings-apply.py --db /config/cwa.db --table cwa_settings --seed /seed/seeds/cwa_settings.json"
	@echo "== apply app settings =="
	ssh "$(HOST)" "docker run --rm --entrypoint python3 -v $(CWA_VOL):/config -v $(HOST_BASE):/seed:ro $(CWA_IMAGE) /seed/settings-apply.py --db /config/app.db --table settings --seed /seed/seeds/app_settings.json --id 1"
	@echo "== install DeDRM into active CWA calibre config =="
	ssh "$(HOST)" "docker run --rm -v $(CWA_VOL):/config -v $(HOST_BASE)/seeds/dedrm:/dedrm:ro $(CWA_IMAGE) sh -c 'mkdir -p /config/.config/calibre/plugins && cp /dedrm/DeDRM.zip /config/.config/calibre/plugins/DeDRM.zip && cp /dedrm/customize.py.json /config/.config/calibre/customize.py.json && cp /dedrm/dedrm.json /config/.config/calibre/plugins/dedrm.json'"
	@echo "== start CWA =="
	ssh "$(HOST)" "docker start calibre-web-automated"
	@echo "== set GUI global.py.json (library path) =="
	ssh "$(HOST)" "docker run --rm -v $(GUI_VOL):/config -v $(HOST_BASE)/seeds:/seeds:ro $(GUI_IMAGE) sh -c 'cp /seeds/gui-global.py.json /config/.config/calibre/global.py.json'"
	@echo "== restart GUI to reload =="
	ssh "$(HOST)" "docker restart calibre"
	@echo "seed complete"

calibre-plugins: ## Download (sha-verified), stage, and install GUI plugins
	@mkdir -p /tmp/calibre-plugins
	@printf '%s\n' \
		'import hashlib, json, os, subprocess, sys' \
		'manifest_path, out_dir = sys.argv[1], sys.argv[2]' \
		'manifest = json.load(open(manifest_path))' \
		'failures = []' \
		'for key, entry in manifest.items():' \
		'    local = os.path.join(out_dir, f"{key}.zip")' \
		'    if os.path.exists(local):' \
		'        os.remove(local)' \
		'    subprocess.run(["curl", "-sL", "--max-time", "60", "-o", local, entry["url"]], check=True)' \
		'    h = hashlib.sha256(open(local, "rb").read()).hexdigest()' \
		'    if h != entry["sha256"]:' \
		'        failures.append(f"{key}: expected {entry['"'"'sha256'"'"']} got {h}")' \
		'        continue' \
		'    print(f"OK {key} {h}")' \
		'if failures:' \
		'    print("SHA256 MISMATCH — aborting:", *failures, sep="\n  ")' \
		'    sys.exit(1)' \
		| python3 - "$(CALIBRE_DIR)/plugins/manifest.json" "/tmp/calibre-plugins"
	rsync -av --delete /tmp/calibre-plugins/ "$(HOST):$(HOST_BASE)/plugins/zips/"
	@for key in $$(cd $(CALIBRE_DIR)/plugins && python3 -c 'import json,sys;print(" ".join(json.load(open("manifest.json")).keys()))'); do \
		echo "== install $$key =="; \
		ssh "$(HOST)" "docker stop calibre || true"; \
		ssh "$(HOST)" "docker run --rm -e HOME=/config -v $(GUI_VOL):/config -v $(HOST_BASE)/plugins/zips/$$key.zip:/plugin.zip:ro $(GUI_IMAGE) calibre-customize --add-plugin=/plugin.zip"; \
		ssh "$(HOST)" "docker start calibre"; \
	done
	@echo "plugins installed"

calibre-check: ## Verify running state: containers up, GUI plugins list, CWA kobo endpoint
	@ssh "$(HOST)" "docker ps --format '{{.Names}} {{.Status}}' | grep -E '^calibre[ -]'"
	@ssh "$(HOST)" "docker exec calibre calibre-customize --list-plugins | grep -iE 'Kobo|Quality|Manage|EpubMerge|Kindle' | head"
	@ssh "$(HOST)" "docker exec calibre-web-automated python3 -c \"import sqlite3;c=sqlite3.connect('/config/app.db');print('kobo_sync=',c.execute('SELECT config_kobo_sync FROM settings').fetchone()[0])\""