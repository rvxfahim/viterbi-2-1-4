# Portable build for the original C++ reference model.
#
# The .sln / .vcxproj next to this file are the author's original MSVC project
# and are kept for provenance.  This adds a toolchain-independent way to build
# the same source with g++ or clang:
#
#     cmake -S model/cpp -B build/cpp && cmake --build build/cpp
#     ./build/cpp/viterbi_2_1_4

cmake_minimum_required(VERSION 3.16)
project(viterbi_2_1_4 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(viterbi_2_1_4 viterbi_2_1_4.cpp)
