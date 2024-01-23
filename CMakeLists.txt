#
# Multi-config generator, e.g. Visual Studio on Windows:
#
# cmake -S c-marpaESLIFPerl -B c-marpaESLIFPerl-build
# cmake --build c-marpaESLIFPerl-build --config RelWithDebInfo
# ctest --test-dir c-marpaESLIFPerl-build -C RelWithDebInfo
# Windows:
#   cmake --install c-marpaESLIFPerl-build --config RelWithDebInfo --prefix %cd%/c-marpaESLIFPerl-install
# Others:
#   cmake --install c-marpaESLIFPerl-build --config RelWithDebInfo --prefix `pwd`/c-marpaESLIFPerl-install
# cmake --build c-marpaESLIFPerl-build --config RelWithDebInfo --target package
#
# Single-config generator, e.g. NMake Makefiles on Windows, Unix Makefiles on Linxu:
#
# cmake -S c-marpaESLIFPerl -B c-marpaESLIFPerl-build -DCMAKE_BUILD_TYPE=RelWithDebInfo
# cmake --build c-marpaESLIFPerl-build
# ctest --test-dir c-marpaESLIFPerl-build
# Windows:
#   cmake --install c-marpaESLIFPerl-build --prefix %cd%/c-marpaESLIFPerl-install
# Others:
#   cmake --install c-marpaESLIFPerl-build --prefix `pwd`/c-marpaESLIFPerl-install
# cmake --build c-marpaESLIFPerl-build --target package
#
# Local tests done with: cmake -S c-marpaESLIFPerl -B c-marpaESLIFPerl-build -DCMAKE_HELPERS_DEBUG=OFF -DICU_ROOT=C:\icu4c-74_2-Win64-MSVC2019
#
cmake_minimum_required(VERSION 3.26.0 FATAL_ERROR)
project(marpaESLIFPerl LANGUAGES C) # We will set version later
#
# Option to install perl dependencies. OFF is the default: packagers are assumed to
# have already pre-installed on their builders.
#
option(INSTALL_DEPENDENCIES "Install Perl dependencies" OFF)
#
# PROJECT_VERSION: see below. we will inherit marpaESLIF's PROJECT_VESION, and increment
# only PROJECT_VERSION_TWEAK
#
set(PROJECT_VERSION_TWEAK 1)
#
# We require perl
#
find_package(Perl REQUIRED)
#
# Manage perl required dependencies
#
if(INSTALL_DEPENDENCIES)
  if(WIN32 AND NOT CYGWIN)
    set(cpanm_name cpanm.bat)
  else()
    set(cpanm_name cpanm)
  endif()
  #
  # - cpanm bootstrap
  #
  message(STATUS "Checking for ${cpanm_name}")
  find_program(CPANM ${cpanm_name})
  if(CPANM)
    message(STATUS "Checking for ${cpanm_name} - ${CPANM}")
  else()
    message(STATUS "Installing App::cpanminus")
    set(perl_input ${CMAKE_CURRENT_BINARY_DIR}/perl_input)
    file(WRITE ${perl_input} "install App::cpanminus\n")
    message(STATUS "Checking for App::cpanminus")
    execute_process(
      COMMAND ${PERL_EXECUTABLE} -MCPAN -e shell
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      INPUT_FILE ${perl_input}
      COMMAND_ERROR_IS_FATAL ANY
    )
    find_program(CPANM ${cpanm_name} REQUIRED)
  endif()
  #
  # - Packages
  #
  foreach(_package
      Dist::Zilla
      Dist::Zilla::Plugin::Git::NextVersion
      Dist::Zilla::Plugin::OurPkgVersion
      Dist::Zilla::Plugin::Authority
      Dist::Zilla::Plugin::Git::Contributors
      Dist::Zilla::Plugin::PodWeaver
      Dist::Zilla::Plugin::Prereqs::AuthorDeps
      Dist::Zilla::Plugin::Test::Perl::Critic
      Dist::Zilla::Plugin::MetaTests
      Dist::Zilla::Plugin::Test::EOL
      Dist::Zilla::Plugin::Test::MinimumVersion
      Dist::Zilla::Plugin::MojibakeTests
      Dist::Zilla::Plugin::Test::NoTabs
      Dist::Zilla::Plugin::PodCoverageTests
      Dist::Zilla::Plugin::Test::Pod::LinkCheck
      Dist::Zilla::Plugin::Test::Portability
      Dist::Zilla::Plugin::Test::Synopsis
      Dist::Zilla::Plugin::Test::Version
      Dist::Zilla::Plugin::Test::CPAN::Changes
      Dist::Zilla::Plugin::Test::Kwalitee
      Dist::Zilla::Plugin::Test::CPAN::Meta::JSON
      Dist::Zilla::Plugin::AutoMetaResources
      Dist::Zilla::Plugin::GitHub::Meta
      Dist::Zilla::Plugin::FileFinder::ByName
      Dist::Zilla::Plugin::AutoPrereqs
      Dist::Zilla::Plugin::MinimumPerl
      Dist::Zilla::Plugin::CPANFile
      Dist::Zilla::Plugin::ChangelogFromGit::CPAN::Changes
      Dist::Zilla::PluginBundle::Starter::Git
      Dist::Zilla::Plugin::DynamicPrereqs
      Pod::Weaver::PluginBundle::RJBS
      Dist::Zilla::Plugin::Git::GatherDir
      Dist::Zilla::Plugin::AlienBuild
      #
      # We have an alienfile that is a modified versio of Alien::cmake3
      # Let's pull in Alien::cmake3 and its explicit dependencies
      #
      Alien::cmake3
      Alien::Build
      File::Which
      Path::Tiny
      Capture::Tiny
      Alien::Build::Plugin::Build::Autoconf
      #
      # We use ExtUtils::Constant to create constants
      #
      ExtUtils::Constant
    )
    message(STATUS "Checking for ${_package}")
    execute_process(
      COMMAND ${CPANM} -n ${_package}
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      COMMAND_ERROR_IS_FATAL ANY
    )
  endforeach()
endif()
#
# Dist::Zilla caller
#
set(DIST_ZILLA_APP_RUN "\"Dist::Zilla::App->run\"")
#
# marpaESLIFPerlCopy
#
add_custom_target(marpaESLIFPerlCopy
  COMMAND ${CMAKE_COMMAND} -E rm -rf dist.ini t lib
  COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/dist.ini dist.ini
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/t t
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/lib lib
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
#
# marpaESLIFPerlPackage
#
add_custom_target(marpaESLIFPerlPackage ALL
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- build --verbose
  DEPENDS marpaESLIFPerlCopy
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
#
# marpaESLIFPerlClean
#
add_custom_target(marpaESLIFPerlClean
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- clean --verbose
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
#
# marpaESLIFPerlReleaseTrial
#
add_custom_target(marpaESLIFPerlReleaseTrial
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- release --trial --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- release --trial --verbose
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

#
# marpaESLIFPerlRelease
#
add_custom_target(marpaESLIFPerlRelease
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- release --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- release --verbose
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
#
# marpaESLIFPerlTest
#
add_custom_target(marpaESLIFPerlTest
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- test --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- test --verbose
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
#
# marpaESLIFPerlXtest
#
add_custom_target(marpaESLIFPerlXtest
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- xtest --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- xtest --verbose
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
