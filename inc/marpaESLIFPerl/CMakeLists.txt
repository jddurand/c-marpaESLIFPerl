cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
project(marpaESLIFPerl)
#
# Get library helper
#
include(FetchContent)
FetchContent_Declare(cmake-helpers URL $ENV{CMAKE_HELPERS_DEPEND_CMAKE-HELPERS_FILE})
FetchContent_MakeAvailable(cmake-helpers)
#
# C.f. the with environment variables
#
cmake_helpers_depend(marpaESLIF
  FIND_PACKAGE_ARGS REQUIRED CONFIG
)
