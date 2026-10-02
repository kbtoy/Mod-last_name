# AzerothCore module: mod-last_name
cmake_minimum_required(VERSION 3.16)

set(MOD_LAST_NAME_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

add_library(mod-last_name INTERFACE)

target_sources(mod-last_name INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/mod_last_name.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/last_name_loader.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/last_name_registry.cpp
)

target_include_directories(mod-last_name INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(mod-last_name INTERFACE
    game
)
