include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(subprocestest_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(subprocestest_setup_options)
  option(subprocestest_ENABLE_HARDENING "Enable hardening" ON)
  option(subprocestest_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    subprocestest_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    subprocestest_ENABLE_HARDENING
    OFF)

  subprocestest_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR subprocestest_PACKAGING_MAINTAINER_MODE)
    option(subprocestest_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(subprocestest_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(subprocestest_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(subprocestest_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(subprocestest_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(subprocestest_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(subprocestest_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(subprocestest_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(subprocestest_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(subprocestest_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(subprocestest_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(subprocestest_ENABLE_PCH "Enable precompiled headers" OFF)
    option(subprocestest_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(subprocestest_ENABLE_IPO "Enable IPO/LTO" ON)
    option(subprocestest_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(subprocestest_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(subprocestest_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(subprocestest_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(subprocestest_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(subprocestest_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(subprocestest_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(subprocestest_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(subprocestest_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(subprocestest_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(subprocestest_ENABLE_PCH "Enable precompiled headers" OFF)
    option(subprocestest_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      subprocestest_ENABLE_IPO
      subprocestest_WARNINGS_AS_ERRORS
      subprocestest_ENABLE_USER_LINKER
      subprocestest_ENABLE_SANITIZER_ADDRESS
      subprocestest_ENABLE_SANITIZER_LEAK
      subprocestest_ENABLE_SANITIZER_UNDEFINED
      subprocestest_ENABLE_SANITIZER_THREAD
      subprocestest_ENABLE_SANITIZER_MEMORY
      subprocestest_ENABLE_UNITY_BUILD
      subprocestest_ENABLE_CLANG_TIDY
      subprocestest_ENABLE_CPPCHECK
      subprocestest_ENABLE_COVERAGE
      subprocestest_ENABLE_PCH
      subprocestest_ENABLE_CACHE)
  endif()

  subprocestest_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (subprocestest_ENABLE_SANITIZER_ADDRESS OR subprocestest_ENABLE_SANITIZER_THREAD OR subprocestest_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(subprocestest_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(subprocestest_global_options)
  if(subprocestest_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    subprocestest_enable_ipo()
  endif()

  subprocestest_supports_sanitizers()

  if(subprocestest_ENABLE_HARDENING AND subprocestest_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR subprocestest_ENABLE_SANITIZER_UNDEFINED
       OR subprocestest_ENABLE_SANITIZER_ADDRESS
       OR subprocestest_ENABLE_SANITIZER_THREAD
       OR subprocestest_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${subprocestest_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${subprocestest_ENABLE_SANITIZER_UNDEFINED}")
    subprocestest_enable_hardening(subprocestest_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(subprocestest_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(subprocestest_warnings INTERFACE)
  add_library(subprocestest_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  subprocestest_set_project_warnings(
    subprocestest_warnings
    ${subprocestest_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(subprocestest_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(subprocestest_options)
  endif()

  include(cmake/Sanitizers.cmake)
  subprocestest_enable_sanitizers(
    subprocestest_options
    ${subprocestest_ENABLE_SANITIZER_ADDRESS}
    ${subprocestest_ENABLE_SANITIZER_LEAK}
    ${subprocestest_ENABLE_SANITIZER_UNDEFINED}
    ${subprocestest_ENABLE_SANITIZER_THREAD}
    ${subprocestest_ENABLE_SANITIZER_MEMORY})

  set_target_properties(subprocestest_options PROPERTIES UNITY_BUILD ${subprocestest_ENABLE_UNITY_BUILD})

  if(subprocestest_ENABLE_PCH)
    target_precompile_headers(
      subprocestest_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(subprocestest_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    subprocestest_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(subprocestest_ENABLE_CLANG_TIDY)
    subprocestest_enable_clang_tidy(subprocestest_options ${subprocestest_WARNINGS_AS_ERRORS})
  endif()

  if(subprocestest_ENABLE_CPPCHECK)
    subprocestest_enable_cppcheck(${subprocestest_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(subprocestest_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    subprocestest_enable_coverage(subprocestest_options)
  endif()

  if(subprocestest_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(subprocestest_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(subprocestest_ENABLE_HARDENING AND NOT subprocestest_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR subprocestest_ENABLE_SANITIZER_UNDEFINED
       OR subprocestest_ENABLE_SANITIZER_ADDRESS
       OR subprocestest_ENABLE_SANITIZER_THREAD
       OR subprocestest_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    subprocestest_enable_hardening(subprocestest_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
