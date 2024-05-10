cmake_minimum_required (VERSION 2.6)
project (botnix-option)

set(NIX_DEV_INCLUDEPATH "" CACHE STRING "path to nix include directory")

add_executable(botnix-option botnix-option.cc libnix-copy-paste.cc)
target_include_directories(botnix-option PUBLIC "${NIX_DEV_INCLUDEPATH}")
target_link_libraries(botnix-option PRIVATE -lnixmain -lnixexpr -lnixstore -lnixutil -lnixcmd)
target_compile_features(botnix-option PRIVATE cxx_std_20)

install (TARGETS botnix-option DESTINATION bin)
