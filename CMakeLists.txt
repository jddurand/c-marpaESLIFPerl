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
#
# It is VERY important to keep the marpaESLIFPerl version in sync with marpaESLIF.
# I did not found an easy portable way to do so, especially since when marpaESLIF was
# splitted in marpaESLIF and marpaESLIFPerl.
#
project(marpaESLIFPerl VERSION 6.0.35 LANGUAGES C CXX)
#
# Option to install perl dependencies. OFF is the default: packagers are assumed to
# have already pre-installed on their builders.
#
option(INSTALL_DEPENDENCIES "Install Perl dependencies" OFF)
#
# Get library helper
#
include(FetchContent)
if("x$ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE}" STREQUAL "x")
  FetchContent_Declare(cmake-helpers GIT_REPOSITORY https://github.com/jddurand/cmake-helpers.git GIT_SHALLOW TRUE)
else()
  FetchContent_Declare(cmake-helpers URL $ENV{CMAKE_HELPERS_DEPEND_CMAKE_HELPERS_FILE})
endif()
FetchContent_MakeAvailable(cmake-helpers)
#
# marpaESLIF dependency (DEV: How to get it to work with a branch ? Does not for me if I use origin/<branch name>
#
set(marpaESLIF_git https://github.com/jddurand/c-marpaESLIF.git)
cmake_helpers_depend(marpaESLIF
  EXTERNALPROJECT_ADD_ARGS GIT_REPOSITORY ${marpaESLIF_git} GIT_SHALLOW TRUE
  CMAKE_ARGS -DPREFER_STATIC_DEPENDENCIES=ON
  FIND FALSE # We force a build of marpaESLIF
)
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
      # Dist::Zilla::Plugin::Test::EOL # yells on Windows when it should not IMHO
      Dist::Zilla::Plugin::Test::MinimumVersion
      Dist::Zilla::Plugin::MojibakeTests
      Dist::Zilla::Plugin::Test::NoTabs
      Dist::Zilla::Plugin::PodCoverageTests
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
      Dist::Zilla::Plugin::Test::Pod::Coverage::Configurable
      #
      # Non CORE Build requirements
      # ===========================
      Config::AutoConf
      Cwd
      ExtUtils::CBuilder
      ExtUtils::Constant
      # ExtUtils::CppGuess does not install everywhere, we provide it and do a try/catch
      File::chdir
      File::Path
      File::Spec
      File::Temp
      File::Which
      Probe::Perl
      Perl::OSType
      Try::Tiny
      #
      # lib and t requirements
      # ======================
      Carp
      Data::Dumper
      Encode
      Log::Any::Adapter
      Log::Any
      Math::BigFloat
      Math::BigInt
      Pod::Coverage::TrustPod
      Safe::Isa
      Test::CPAN::Changes
      Test::CPAN::Meta
      Test::CPAN::Meta::JSON
      Test::Deep
      # Test::EOL # yells on Windows when it should not IMHO
      Test::Kwalitee
      Test::MinimumVersion
      Test::Mojibake
      Test::More
      Test::More::UTF8
      Test::NoTabs
      Test::Perl::Critic
      Test::Pod
      Test::Pod::Coverage
      Test::Portability::Files
      Test::Synopsis
      Test::Version
      Try::Tiny
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
# Make tarballs of dependencies
#
file(GLOB deps LIST_DIRECTORIES true "${CMAKE_HELPERS_FETCHCONTENT_BASE_DIR}/*-src")
set(create_tar_gz-pl ${CMAKE_CURRENT_SOURCE_DIR}/etc/create_tar_gz.pl)
set(deps-tgz)
set(tarballs-destdir ${CMAKE_CURRENT_SOURCE_DIR}/etc/tarballs)
execute_process(COMMAND ${CMAKE_COMMAND} -E rm -rf ${tarballs-destdir})
execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory ${tarballs-destdir})
foreach(dep IN LISTS deps)
  cmake_path(GET dep FILENAME depname_src)
  #
  # Skip things that are not need or bundled
  #
  if(
      (depname_src STREQUAL marpaeslifperl-src) # Ourself...
      OR
      (depname_src STREQUAL cmake-helpers-src)  # Not needed
      OR
      (depname_src STREQUAL libiconv-src)       # Bundled in tconv
      OR
      (depname_src STREQUAL optparse-src)       # Not needed
      OR
      (depname_src STREQUAL pcre2-src)          # Bundled in marpaESLIF
    )
    continue()
  endif()
  set(dep-tgz ${tarballs-destdir}/${depname_src}.tar.gz)
  add_custom_command(
    OUTPUT ${dep-tgz}
    COMMAND ${PERL_EXECUTABLE} ${create_tar_gz-pl} ${dep-tgz} .
    DEPENDS ${create_tar_gz-pl}
    WORKING_DIRECTORY ${dep}
  )
  list(APPEND deps-tgz ${dep-tgz})
endforeach()
#
# marpaESLIFPerlPackage
#
add_custom_target(marpaESLIFPerlPackage ALL
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- build --verbose
  DEPENDS ${deps-tgz}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
#
# marpaESLIFPerlClean
#
add_custom_target(marpaESLIFPerlClean
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- clean --verbose
  DEPENDS ${deps-tgz}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
#
# marpaESLIFPerlReleaseTrial
#
add_custom_target(marpaESLIFPerlReleaseTrial
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- release --trial --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- release --trial --verbose
  DEPENDS ${deps-tgz}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
#
# marpaESLIFPerlRelease
#
add_custom_target(marpaESLIFPerlRelease
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- release --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- release --verbose
  DEPENDS ${deps-tgz}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
#
# marpaESLIFPerlTest
#
add_custom_target(marpaESLIFPerlTest
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- test --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- test --verbose
  DEPENDS ${deps-tgz}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
#
# marpaESLIFPerlXtest
#
add_custom_target(marpaESLIFPerlXtest
  ${CMAKE_COMMAND} -E echo "${PERL_EXECUTABLE} -MDist::Zilla::App -e ${DIST_ZILLA_APP_RUN} -- xtest --verbose"
  COMMAND ${PERL_EXECUTABLE} -MDist::Zilla::App -e "${DIST_ZILLA_APP_RUN}" -- xtest --verbose
  DEPENDS ${deps-tgz}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
