# Makefile for building the Arrow sparse static library and Crystal application

# Compiler settings
CXX = g++
CXXFLAGS = -std=c++11 -fPIC -O2 -Wall

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

.PHONY: all clean install test

# Default target: build static library
all: $(STATIC_LIB)

# Build static library
$(STATIC_LIB): $(CPP_OBJECTS)
	ar rcs $@ $^

# Compile C++ object files
%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Build Crystal application (depends on static library)
$(CRYSTAL_APP): $(STATIC_LIB)
	crystal build $(CRYSTAL_SOURCE) $(CRYSTAL_FLAGS) -o $@

# Clean build artifacts
clean:
	rm -f $(CPP_OBJECTS) $(STATIC_LIB) $(CRYSTAL_APP)

# Install static library to system
install: $(STATIC_LIB)
	cp $(STATIC_LIB) /usr/local/lib/ || sudo cp $(STATIC_LIB) /usr/local/lib/

# Test: build Crystal application
test: $(CRYSTAL_APP)
	@echo "Build completed successfully: $(CRYSTAL_APP)"
