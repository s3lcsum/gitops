.PHONY: help serve build clean lint icons consistency consistency-fix test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

## Consistency — verify the repo's "single sources of truth" agree (see scripts/check-consistency.py)
consistency: ## Report consistency drift between Traefik hosts, blackbox, homepage, Authentik (read-only)
	python3 scripts/check-consistency.py

consistency-fix: ## Repair auto-fixable drift (blackbox promscrape + homepage services); exits non-zero if terraform/README need manual review
	python3 scripts/check-consistency.py --fix

test: ## Security invariants + consistency (read-only)
	python3 scripts/test_security_invariants.py
	python3 scripts/check-consistency.py
	node --test terraform/cloudflare/shorturl.test.mjs

serve: ## Start MkDocs development server (http://localhost:8000)
	uvx --with mkdocs-material --with mkdocs-git-revision-date-localized-plugin mkdocs serve

build: ## Build static site to site/ directory
	uvx --with mkdocs-material --with mkdocs-git-revision-date-localized-plugin mkdocs build --strict

clean: ## Remove generated site directory
	rm -rf site

lint: ## Check documentation for broken links and issues
	uvx --with mkdocs-material --with mkdocs-git-revision-date-localized-plugin mkdocs build --strict 2>&1 | grep -E "(WARNING|ERROR)" || echo "No issues found"
