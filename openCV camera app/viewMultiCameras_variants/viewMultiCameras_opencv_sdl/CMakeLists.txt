cmake_minimum_required(VERSION 3.16)
project(viewMultiCameras_opencv_sdl LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED sdl2)

find_package(OpenCV REQUIRED)

add_executable(viewMultiCameras_opencv_sdl main.cpp)

target_include_directories(viewMultiCameras_opencv_sdl PRIVATE
  ${SDL2_INCLUDE_DIRS}
  ${OpenCV_INCLUDE_DIRS}
)

target_link_libraries(viewMultiCameras_opencv_sdl PRIVATE
  ${SDL2_LIBRARIES}
  ${OpenCV_LIBS}
)

target_compile_options(viewMultiCameras_opencv_sdl PRIVATE
  ${SDL2_CFLAGS_OTHER}
)
