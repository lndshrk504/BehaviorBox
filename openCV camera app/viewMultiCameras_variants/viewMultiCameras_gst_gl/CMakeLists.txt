cmake_minimum_required(VERSION 3.16)
project(viewMultiCameras_gst_gl LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED sdl2)
pkg_check_modules(GST REQUIRED gstreamer-1.0 gstreamer-video-1.0 gstreamer-gl-1.0)

add_executable(viewMultiCameras_gst_gl main.cpp)

target_include_directories(viewMultiCameras_gst_gl PRIVATE
  ${SDL2_INCLUDE_DIRS}
  ${GST_INCLUDE_DIRS}
)

target_link_libraries(viewMultiCameras_gst_gl PRIVATE
  ${SDL2_LIBRARIES}
  ${GST_LIBRARIES}
)

target_compile_options(viewMultiCameras_gst_gl PRIVATE
  ${SDL2_CFLAGS_OTHER}
  ${GST_CFLAGS_OTHER}
)
