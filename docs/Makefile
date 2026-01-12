# MkDocs documentation management
# Run targets from the docs/ directory or use: make -C docs <target>
# Uses uv for fast Python package management

.PHONY: help serve build clean lint icons



help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

serve: ## Start MkDocs development server (http://localhost:8000)
	uvx --with mkdocs-material --with mkdocs-git-revision-date-localized-plugin mkdocs serve -f ../mkdocs.yml

build: ## Build static site to site/ directory
	uvx --with mkdocs-material --with mkdocs-git-revision-date-localized-plugin mkdocs build -f ../mkdocs.yml --strict

clean: ## Remove generated site directory
	rm -rf ../site

lint: ## Check documentation for broken links and issues
	uvx --with mkdocs-material --with mkdocs-git-revision-date-localized-plugin mkdocs build -f ../mkdocs.yml --strict 2>&1 | grep -E "(WARNING|ERROR)" || echo "No issues found"
