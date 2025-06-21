# Makefile for building the Arrow sparse library

CXX = g++
CXXFLAGS = -std=c++11 -fPIC -O2 -Wall
LDFLAGS = -shared

# Library name
LIB_NAME = libarrow_sparse
LIB_EXT = so
ifeq ($(shell uname -s),Darwin)
	LIB_EXT = dylib
	LDFLAGS += -undefined dynamic_lookup
endif

# Source files
SOURCES = src/arrow_sparse.cpp
OBJECTS = $(SOURCES:.cpp=.o)
TARGET = $(LIB_NAME).$(LIB_EXT)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(LDFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)

install: $(TARGET)
	cp $(TARGET) /usr/local/lib/ || sudo cp $(TARGET) /usr/local/lib/

.PHONY: test
test: $(TARGET)
	crystal build src/kc.cr -Dpreview_mt -Dexecution_context
