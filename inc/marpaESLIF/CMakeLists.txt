cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
project(marpaESLIFDownload)
#
# Get library helper
#
include(FetchContent)
FetchContent_Declare(cmake-helpers GIT_REPOSITORY https://github.com/jddurand/cmake-helpers.git GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(cmake-helpers)
#
# marpaESLIF dependency (DEV: How to get it to work with a branch ? Does not for me if I use origin/<branch name>
#
set(marpaESLIF_git https://github.com/jddurand/c-marpaESLIF.git)
cmake_helpers_depend(marpaESLIF
  EXTERNALPROJECT_ADD_ARGS DOWNLOAD_COMMAND ${GIT_EXECUTABLE} clone --single-branch --branch cmake_helpers ${marpaESLIF_git} ${CMAKE_CURRENT_BINARY_DIR}/_deps/marpaeslif-src
  FIND_PACKAGE_ARGS REQUIRED CONFIG
)
