#Some organization borrowed from: https://github.com/tscott8706/cpp-csv-col-replacer/blob/master

# Build executable with:
# % make
# Delete object files and executable with:
# % make clean
# Rebuild all objects and executable with:
# % make -B

SRC_DIR := src
INCLUDE_DIR := inc
OBJ_DIR := build
BIN_DIR := bin
LIB_DIR := lib
LIB_OBJ_DIR := lib/build
TEST_SRC_DIR := test/src
TEST_OBJ_DIR := test/build
LIB := $(LIB_DIR)/libcupss.a

EXECUTABLE := cupss
RANDOM_EXECUTABLE := noise_gen
TEST_EXECUTABLE := test_cupss
SOURCES := $(wildcard $(SRC_DIR)/*.cpp)
SOURCES_CU := $(wildcard $(SRC_DIR)/*.cu)
SOURCES_NO_MAIN := $(filter-out $(SRC_DIR)/main.cpp,$(SOURCES))
SOURCES_NO_MAIN_CU := $(filter-out $(SRC_DIR)/main.cpp,$(SOURCES_CU))
RANDOM_SOURCES := $(wildcard active-noise/*.cu)
TEST_SOURCES := $(wildcard $(TEST_SRC_DIR)/*.cpp)
#TEST_SOURCES += $(wildcard $(TEST_SRC_DIR)/*.cu)
HEADERS := $(wildcard $(INCLUDE_DIR)/*.h)
HEADERS += $(wildcard $(INCLUDE_DIR)/*.cuh)
TEST_HEADERS := $(wildcard $(TEST_SRC_DIR)/*.h)
TEST_HEADERS += $(wildcard $(TEST_SRC_DIR)/*.cuh)

CXX := nvcc
#CXX := h5c++

SHELL = /bin/sh

# Flags to pass to the compiler; per the reccomendations of the GNU Scientific Library
CXXFLAGS:= -std=c++17 -DWITHCUDA -I$(HOME)/.local/include -I$(FFTW_ROOT)/include

# Compiler flags controling optimization levels. Use -O3 for full optimization,
# but make sure your results are consistent
# -g includes debugging information. You can also add -pg here for profiling 
PROFILE=-pg
OPTFLAGS:=$(PROFILE) -O2 -g #Might try changing to O3 to increase speed

# Flags to pass to the linker; -lm links in the standard c math library
#LDFLAGS:= -lm -lgsl -lgslcblas -lopenblas -larmadillo -lstdc++fs -langen -lfftw3 -lhdf5 -lhdf5_cpp $(PROFILE) -L$(HOME)/.local/lib 
LDFLAGS:= -lstdc++fs -lfftw3f -L$(FFTW_ROOT)/lib -L$(CUDA_MATH_LIB) -lcufft -L$(CUDA_MATH_LIB) -lcurand -lcupss -L$(HOME)/.local/lib $(PROFILE) 
#LDLIBFLAGS:= -lm -lgsl -lgslcblas -lopenblas -larmadillo -lstdc++fs -langen -Wl,--no-as-needed -lhdf5 -lhdf5_cpp $(PROFILE) -L$(HOME)/.local/lib 
LDLIBFLAGS:= -lstdc++fs -lfftw3 -L$(FFTW_ROOT)/lib -L$(HOME)/.local/lib $(PROFILE)

# Variable to compose names of object files from the names of sources
OBJECTS := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SOURCES))
OBJECTS += $(patsubst $(SRC_DIR)/%.cu,$(OBJ_DIR)/%.o,$(SOURCES))
OBJECTS_RANDOM := $(patsubst active-noise/%.cu,$(OBJ_DIR)/%.o,$(RANDOM_SOURCES))
OBJECTS_NO_MAIN := $(filter-out $(OBJ_DIR)/main.o,$(OBJECTS))
OBJECTS_LIB := $(patsubst $(SRC_DIR)/%.cpp,$(LIB_OBJ_DIR)/%.o,$(SOURCES_NO_MAIN))
OBJECTS_LIB_CU := $(patsubst $(SRC_DIR)/%.cu,$(LIB_OBJ_DIR)/%.o,$(SOURCES_NO_MAIN_CU))

#When compiling tests, include all objects in actual program except for main
#(there's a main function in the test folder)
TEST_OBJECTS := $(patsubst $(TEST_SRC_DIR)/%.cpp,$(TEST_OBJ_DIR)/%.o,$(TEST_SOURCES))
TEST_OBJECTS += $(OBJECTS_NO_MAIN)

# Default target depends on sources and headers to detect changes
all: $(SOURCES) $(HEADERS) $(BIN_DIR)/$(EXECUTABLE)
lib: $(LIB)
	install $(LIB) $(HOME)/.local/lib/
	mkdir -p $(HOME)/.local/include/cupss
	install $(HEADERS) $(HOME)/.local/include/cupss/
random: $(RANDOM_SOURCES) $(HEADERS) $(BIN_DIR)/$(RANDOM_EXECUTABLE)
	install $(BIN_DIR)/$(RANDOM_EXECUTABLE) $(HOME)/.local/bin/
install: 
	install bin/* $(HOME)/.local/bin/
test: $(TEST_SOURCES) $(TEST_HEADERS) $(BIN_DIR)/$(TEST_EXECUTABLE)

#Compile .cpp files to object files
$(OBJ_DIR)/%.o : $(SRC_DIR)/%.cpp
	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) $< -o $@
$(LIB_OBJ_DIR)/%.o : $(SRC_DIR)/%.cpp
	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) $< -o $@
$(TEST_OBJ_DIR)/%.o : $(TEST_SRC_DIR)/%.cpp
	$(CXX) -c $(CXXFLAGS) $< -o $@

#Compile .cu files to object files
#$(OBJECTS_RANDOM)/%.o : active-noise/%.cu
#	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) $< -o $@
$(OBJ_DIR)/%.o : $(SRC_DIR)/%.cu
	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) $< -o $@
$(LIB_OBJ_DIR)/%.o : $(SRC_DIR)/%.cu
	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) $< -o $@
$(TEST_OBJ_DIR)/%.o : $(TEST_SRC_DIR)/%.cu
	$(CXX) -c $(CXXFLAGS) $< -o $@

# Build the executable by linking all objects
$(BIN_DIR)/$(EXECUTABLE): $(OBJECTS)
	$(CXX) $(OBJECTS) $(LDFLAGS) -o $@
$(BIN_DIR)/$(RANDOM_EXECUTABLE) : $(OBJECTS_RANDOM)
	$(CXX) $(OBJECTS_RANDOM) $(LDFLAGS) -o $@
$(LIB): $(OBJECTS_LIB) $(OBJECTS_LIB_CU)
	ar rcs $(LIB) $(LIB_OBJ_DIR)/*o
$(BIN_DIR)/$(TEST_EXECUTABLE): $(TEST_OBJECTS)
	$(CXX) $(TEST_OBJECTS) $(LDFLAGS) -o $@

# clean up so we can start over (removes executable!)
clean:
	rm -f $(OBJ_DIR)/*.o $(LIB_OBJ_DIR)/*.o $(TEST_OBJ_DIR)/*.o $(BIN_DIR)/$(EXECUTABLE) $(BIN_DIR)/$(TEST_EXECUTABLE) $(LIB_DIR)/*.a
