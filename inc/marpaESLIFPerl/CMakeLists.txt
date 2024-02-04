cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
project(marpaESLIFPerl)
#
# Get library helper
#
include(FetchContent)
message(STATUS "\$ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE}: $ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE}")
FetchContent_Declare(cmake-helpers URL $ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE})
FetchContent_MakeAvailable(cmake-helpers)
#
# C.f. the hook with environment variables CMAKE_HELPERS_DEPEND_<dep>_FILE
#
cmake_helpers_depend(marpaESLIF
  FIND_PACKAGE_ARGS REQUIRED CONFIG
)
