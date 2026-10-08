# Entry points for operating FeedR — like `npm run` scripts, for the infrastructure repo.
# `make` (or `make help`) lists them. Requires the GitHub CLI logged in: gh auth login

.DEFAULT_GOAL := help
.PHONY: help release release-status

help: ## List available commands
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-16s %s\n", $$1, $$2}'
	@echo
	@echo "  release: BACKEND / FRONTEND = latest | sha-xxxxxxx | - (skip)"
	@echo "    make release BACKEND=latest FRONTEND=latest    weekly release"
	@echo "    make release BACKEND=- FRONTEND=latest         hotfix, frontend only"
	@echo "    make release BACKEND=sha-29d0092 FRONTEND=-    rollback backend"

release: ## Release to production (asks for confirmation, follows the run)
	@scripts/release.sh "$(BACKEND)" "$(FRONTEND)"

release-status: ## Show the last production releases
	@gh run list -R VadimNeVlad/feedr-infrastructure --workflow deploy.yml --limit 10
