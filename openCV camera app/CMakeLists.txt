cmake_minimum_required(VERSION 3.16)
project(viewMultiCameras LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenCV REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED sdl2)

add_executable(viewMultiCameras main.cpp)

target_include_directories(viewMultiCameras PRIVATE
  ${OpenCV_INCLUDE_DIRS}
  ${SDL2_INCLUDE_DIRS}
)

target_link_libraries(viewMultiCameras PRIVATE
  ${OpenCV_LIBS}
  ${SDL2_LIBRARIES}
)

target_compile_options(viewMultiCameras PRIVATE
  ${SDL2_CFLAGS_OTHER}
)
