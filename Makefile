# Makefile for building the Arrow sparse static library and Crystal application

# Compiler settings
CXX = g++
CXXFLAGS = -std=c++17 -fPIC -O2 -Wall

# Arrow C++ library settings
ARROW_CFLAGS = $(shell pkg-config --cflags arrow)
ARROW_LIBS = $(shell pkg-config --libs arrow)

# Library settings
LIB_NAME = libarrow_sparse
STATIC_LIB = $(LIB_NAME).a

# Source files
CPP_SOURCES = src/arrow_sparse.cpp
CPP_OBJECTS = $(CPP_SOURCES:.cpp=.o)

# Crystal application
CRYSTAL_APP = kc
CRYSTAL_SOURCE = src/kc.cr
CRYSTAL_FLAGS = -Dpreview_mt -Dexecution_context

.PHONY: all clean install test check-arrow

# Check if Arrow is available
check-arrow:
	@pkg-config --exists arrow || (echo "Error: Arrow C++ library not found. Please install libarrow-dev or arrow-cpp." && exit 1)

# Default target: build static library
all: check-arrow $(STATIC_LIB)

# Build static library
$(STATIC_LIB): $(CPP_OBJECTS)
	ar rcs $@ $^

# Compile C++ object files with Arrow includes
%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(ARROW_CFLAGS) -c $< -o $@

# Build Crystal application (depends on static library)
$(CRYSTAL_APP): $(STATIC_LIB)
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) --link-flags="$(PWD)/$(STATIC_LIB) $(ARROW_LIBS)" -o $@

# Clean build artifacts
clean:
	rm -f $(CPP_OBJECTS) $(STATIC_LIB) $(CRYSTAL_APP)

# Install static library to system
install: $(STATIC_LIB)
	cp $(STATIC_LIB) /usr/local/lib/ || sudo cp $(STATIC_LIB) /usr/local/lib/

# Test: build Crystal application
test: $(CRYSTAL_APP)
	@echo "Build completed successfully: $(CRYSTAL_APP)"

# Show Arrow configuration
arrow-info:
	@echo "Arrow CFLAGS: $(ARROW_CFLAGS)"
	@echo "Arrow LIBS: $(ARROW_LIBS)"
