cmake_minimum_required(VERSION 3.16)

project(usbcamv4l LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(DEP_X11 REQUIRED IMPORTED_TARGET x11)
pkg_check_modules(DEP_EGL REQUIRED IMPORTED_TARGET egl)
pkg_check_modules(DEP_GLES2 REQUIRED IMPORTED_TARGET glesv2)
pkg_check_modules(DEP_DRM REQUIRED IMPORTED_TARGET libdrm)
pkg_check_modules(DEP_TURBOJPEG REQUIRED IMPORTED_TARGET libturbojpeg)
pkg_check_modules(DEP_AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(DEP_AVUTIL REQUIRED IMPORTED_TARGET libavutil)

add_executable(usbcamv4l main.cpp)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(usbcamv4l PRIVATE -Wall -Wextra -Wpedantic)
endif()

target_link_libraries(usbcamv4l PRIVATE
  PkgConfig::DEP_X11
  PkgConfig::DEP_EGL
  PkgConfig::DEP_GLES2
  PkgConfig::DEP_DRM
  PkgConfig::DEP_TURBOJPEG
  PkgConfig::DEP_AVCODEC
  PkgConfig::DEP_AVUTIL
)
