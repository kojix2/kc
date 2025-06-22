# Makefile for kc - k-mer counter

# Crystal application
CRYSTAL_APP = kc
CRYSTAL_SOURCE = src/kc.cr
CRYSTAL_FLAGS = -Dpreview_mt -Dexecution_context

# C++ Arrow library settings (for arrow format support)
CXX = g++
CXXFLAGS = -std=c++17 -fPIC -O2 -Wall
ARROW_CFLAGS = $(shell pkg-config --cflags arrow 2>/dev/null)
ARROW_LIBS = $(shell pkg-config --libs arrow 2>/dev/null)

# C++ library for Arrow support
STATIC_LIB = libarrow_sparse.a
CPP_SOURCES = src/arrow_sparse.cpp
CPP_OBJECTS = $(CPP_SOURCES:.cpp=.o)

.PHONY: all clean test help check-arrow

# Default target - build with ARSN support only
all: $(CRYSTAL_APP)

# Build with ARSN support only (default)
$(CRYSTAL_APP): 
	@echo "Building kc with ARSN format support..."
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) -o $@

# Build with static linking (for release)
static:
	@echo "Building kc with static linking..."
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) --static -o $(CRYSTAL_APP)

# Build with both Arrow and ARSN support
arrow: check-arrow $(STATIC_LIB)
	@echo "Building kc with Arrow + ARSN format support..."
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) -Dcpp_arrow --link-flags="$(PWD)/$(STATIC_LIB) $(ARROW_LIBS)" -o $(CRYSTAL_APP)

# Check if Arrow is available
check-arrow:
	@pkg-config --exists arrow || (echo "Error: Arrow C++ library not found. Please install libarrow-dev or arrow-cpp." && exit 1)

# Build C++ static library for Arrow support
$(STATIC_LIB): $(CPP_OBJECTS)
	ar rcs $@ $^

# Compile C++ object files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(ARROW_CFLAGS) -c $< -o $@

# Clean build artifacts
clean:
	rm -f $(CPP_OBJECTS) $(STATIC_LIB) $(CRYSTAL_APP)

# Test build
test: $(CRYSTAL_APP)
	@echo "Build completed successfully: $(CRYSTAL_APP)"

# Show help
help:
	@echo "Available targets:"
	@echo "  all        - Build with ARSN format support (default)"
	@echo "  static     - Build with static linking (for release)"
	@echo "  arrow      - Build with Arrow + ARSN format support"
	@echo "  clean      - Clean build artifacts"
	@echo "  test       - Build and test"
	@echo "  check-arrow - Check if Arrow C++ library is available"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Output formats:"
	@echo "  Default build: tsv, sparse, arsn"
	@echo "  Arrow build:   tsv, sparse, arrow, arsn"
