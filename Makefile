# Nexa — sovereign automation surface for the protocol stack.
#
# Usage: make <target>
# Or: nexa <command> (see ops/bin/nexa)

NEXA_ROOT ?= $(shell git rev-parse --show-toplevel 2>/dev/null || echo ".")
export NEXA_ROOT REPO_ROOT := $(NEXA_ROOT)
NEXA := $(NEXA_ROOT)/ops/bin/nexa

.PHONY: help deploy-mesh mesh-full backup docs-bundle smoke-test demo gateway status vault autopilot verify-release zig-docker-distill

help:
	@echo "Nexa — automation targets"
	@echo ""
	@echo "  make deploy-mesh   Deploy in-house Zig gateway surface to VPS"
	@echo "  make mesh-full     Tailscale-aware orchestrator: deploy-mesh + optional smoke (needs VPS_IP)"
	@echo "  make backup       Backup dynamic logs/json/md (local)"
	@echo "  make docs-bundle  Build NotebookLM-safe doc bundle"
	@echo "  make smoke-test   Smoke-test deployed mesh"
	@echo "  make demo         Instant demo: in-house Zig gateway locally"
	@echo "  make gateway      Start gateway only (port 8765)"
	@echo "  make status       System health"
	@echo "  make vault        Vault bootstrap / sync / rotate-token"
	@echo "  make autopilot    Run unified automation control loop status"
	@echo "  make verify-release  Run the hermetic production verification gate"
	@echo "  make zig-docker-distill  Build OCI image (Docker) with nexa-gateway + aura-mcp"
	@echo ""
	@echo "Full CLI: $(NEXA) help"

deploy-mesh:
	$(NEXA) deploy-mesh

mesh-full:
	bash $(NEXA_ROOT)/ops/scripts/meziani-full-mesh.sh

backup:
	$(NEXA) backup

docs-bundle:
	$(NEXA) docs-bundle

smoke-test:
	$(NEXA) smoke-test

demo:
	$(NEXA) demo

gateway:
	$(NEXA) gateway

status:
	$(NEXA) status

vault:
	$(NEXA) vault

autopilot:
	python3 $(NEXA_ROOT)/ops/autopilot/nexa_autopilot.py status

verify-release:
	bash $(NEXA_ROOT)/ops/scripts/verify-release.sh --container

zig-docker-distill:
	bash $(NEXA_ROOT)/ops/scripts/zig-docker-distill.sh
