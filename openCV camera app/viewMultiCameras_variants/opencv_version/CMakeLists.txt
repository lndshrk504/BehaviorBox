cmake_minimum_required(VERSION 3.16)
project(usbcams LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED sdl2)

find_package(OpenCV REQUIRED)

add_executable(usbcams main.cpp)

target_include_directories(usbcams PRIVATE
  ${SDL2_INCLUDE_DIRS}
  ${OpenCV_INCLUDE_DIRS}
)

target_link_libraries(usbcams PRIVATE
  ${SDL2_LIBRARIES}
  ${OpenCV_LIBS}
)

target_compile_options(usbcams PRIVATE
  ${SDL2_CFLAGS_OTHER}
)
