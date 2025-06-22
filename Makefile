# Makefile for building Crystal application with switchable Arrow implementations

# Compiler settings for C++
CXX = g++
CXXFLAGS = -std=c++17 -fPIC -O2 -Wall

# Arrow C++ library settings
ARROW_CFLAGS = $(shell pkg-config --cflags arrow)
ARROW_LIBS = $(shell pkg-config --libs arrow)

# Crystal application
CRYSTAL_APP = kc
CRYSTAL_SOURCE = src/kc.cr

# Arrow implementation selection (default: cpp)
# Use: make ARROW_IMPL=cpp for C++ implementation (default)
# Use: make ARROW_IMPL=crystal for Crystal implementation
ARROW_IMPL ?= cpp

# Library settings for C++ implementation
LIB_NAME = libarrow_sparse
STATIC_LIB = $(LIB_NAME).a
CPP_SOURCES = src/arrow_sparse.cpp
CPP_OBJECTS = $(CPP_SOURCES:.cpp=.o)

# Set Crystal flags and dependencies based on implementation
ifeq ($(ARROW_IMPL),cpp)
  CRYSTAL_FLAGS = -Dpreview_mt -Dexecution_context -Dcpp_arrow
  DEPS = $(STATIC_LIB)
  LINK_FLAGS = --link-flags="$(PWD)/$(STATIC_LIB) $(ARROW_LIBS)"
else
  CRYSTAL_FLAGS = -Dpreview_mt -Dexecution_context
  DEPS = 
  LINK_FLAGS = 
endif

.PHONY: all clean test crystal cpp help check-arrow

# Default target
all: $(CRYSTAL_APP)

# Build with Crystal implementation
crystal:
	$(MAKE) ARROW_IMPL=crystal $(CRYSTAL_APP)

# Check if Arrow is available
check-arrow:
	@pkg-config --exists arrow || (echo "Error: Arrow C++ library not found. Please install libarrow-dev or arrow-cpp." && exit 1)

# Build with C++ implementation  
cpp: check-arrow
	$(MAKE) ARROW_IMPL=cpp $(CRYSTAL_APP)

# Build Crystal application
$(CRYSTAL_APP): $(DEPS)
	@echo "Building with $(ARROW_IMPL) Arrow implementation..."
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) $(LINK_FLAGS) -o $@

# Build C++ static library (only needed for C++ implementation)
$(STATIC_LIB): $(CPP_OBJECTS)
	ar rcs $@ $^

# Compile C++ object files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(ARROW_CFLAGS) -c $< -o $@

# Clean build artifacts
clean:
	rm -f $(CPP_OBJECTS) $(STATIC_LIB) $(CRYSTAL_APP)

# Test: build Crystal application
test: $(CRYSTAL_APP)
	@echo "Build completed successfully: $(CRYSTAL_APP)"

# Show Arrow configuration
arrow-info:
	@echo "Arrow CFLAGS: $(ARROW_CFLAGS)"
	@echo "Arrow LIBS: $(ARROW_LIBS)"

# Show help
help:
	@echo "Available targets:"
	@echo "  all        - Build with default implementation (cpp)"
	@echo "  cpp        - Build with C++ Arrow implementation (default)"
	@echo "  crystal    - Build with custom binary format implementation"
	@echo "  clean      - Clean build artifacts"
	@echo "  test       - Build and test"
	@echo "  check-arrow - Check if Arrow C++ library is available"
	@echo "  arrow-info - Show Arrow library configuration"
	@echo "  help       - Show this help"
	@echo ""
	@echo "You can also use: make ARROW_IMPL=cpp|crystal"
	@echo ""
	@echo "Output formats:"
	@echo "  cpp        - Official Apache Arrow IPC format (ARROW1 header)"
	@echo "  crystal    - Custom sparse binary format (ARSN header)"
