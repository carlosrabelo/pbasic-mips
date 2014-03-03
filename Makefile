MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := help

.PHONY: build clean help run test

EMULATOR ?= spim
MARS_JAR ?= MARS.jar
MIPS_SRC := bin/pbasic.s

help: ## Show available targets
	@echo "pbasic - Available targets"
	@echo ""
	@grep -hE '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "} {printf "  %-15s %s\n", $$1, $$2}'

build: ## Concatenate MIPS sources into a single file
	@./.make/build.sh

test: ## Build, check labels; run 99_test.bas if SPIM is installed
	@./.make/test.sh

run: build ## Build and run on SPIM/MARS emulator
ifeq ($(EMULATOR),mars)
	java -jar $(MARS_JAR) $(MIPS_SRC)
else
	$(EMULATOR) -mapped_io -file $(MIPS_SRC)
endif

clean: ## Remove build artifacts
	rm -f $(MIPS_SRC)
