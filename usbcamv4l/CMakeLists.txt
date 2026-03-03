cmake_minimum_required(VERSION 3.16)

project(usbcamv4l LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(PkgConfig REQUIRED)
find_package(X11 REQUIRED)
find_library(EGL_LIBRARY EGL)
if(NOT EGL_LIBRARY)
  message(FATAL_ERROR "EGL library not found")
endif()

find_library(GLES2_LIBRARY GLESv2)
if(NOT GLES2_LIBRARY)
  message(FATAL_ERROR "GLESv2 library not found")
endif()

pkg_check_modules(LIBDRM REQUIRED IMPORTED_TARGET libdrm)
pkg_check_modules(TURBOJPEG REQUIRED IMPORTED_TARGET libturbojpeg)
pkg_check_modules(LIBAVCODEC REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(LIBAVUTIL REQUIRED IMPORTED_TARGET libavutil)

add_executable(usbcamv4l main.cpp)
target_link_libraries(usbcamv4l PRIVATE
  X11::X11
  ${EGL_LIBRARY}
  ${GLES2_LIBRARY}
  PkgConfig::LIBDRM
  PkgConfig::TURBOJPEG
  PkgConfig::LIBAVCODEC
  PkgConfig::LIBAVUTIL
)

add_executable(usbcamctl usbcamctl.cpp)
