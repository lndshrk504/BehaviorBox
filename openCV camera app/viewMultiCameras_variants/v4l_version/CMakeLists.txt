cmake_minimum_required(VERSION 3.16)
project(usbcamv4l LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")

find_package(PkgConfig REQUIRED)
find_package(X11 REQUIRED)

pkg_check_modules(EGL REQUIRED egl)
pkg_check_modules(GLES2 REQUIRED glesv2)
pkg_check_modules(DRM REQUIRED libdrm)

add_executable(usbcamv4l main.cpp)

target_include_directories(usbcamv4l PRIVATE
  ${X11_INCLUDE_DIR}
  ${EGL_INCLUDE_DIRS}
  ${GLES2_INCLUDE_DIRS}
  ${DRM_INCLUDE_DIRS}
)

target_link_libraries(usbcamv4l PRIVATE
  ${X11_LIBRARIES}
  ${EGL_LIBRARIES}
  ${GLES2_LIBRARIES}
  ${DRM_LIBRARIES}
)

target_compile_options(usbcamv4l PRIVATE
  ${EGL_CFLAGS_OTHER}
  ${GLES2_CFLAGS_OTHER}
  ${DRM_CFLAGS_OTHER}
)
