# Makefile for building Crystal application

# Crystal application
CRYSTAL_APP = kc
CRYSTAL_SOURCE = src/kc.cr
CRYSTAL_FLAGS = -Dpreview_mt -Dexecution_context

.PHONY: all clean test

# Default target: build Crystal application
all: $(CRYSTAL_APP)

# Build Crystal application
$(CRYSTAL_APP):
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) -o $@

# Clean build artifacts
clean:
	rm -f $(CRYSTAL_APP)

# Test: build Crystal application
test: $(CRYSTAL_APP)
	@echo "Build completed successfully: $(CRYSTAL_APP)"
