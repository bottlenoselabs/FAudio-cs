#!/bin/bash
# NOTE: This script builds the FAudio C/C++ library using CMake as a shared library (.dll/.so/.dylib) for the purposes of P/Invoke with C#.
# INPUT:
#   $1: The target operating system to build the shared library for. Possible values are "host", "windows", "linux", "macos".
#   $2: The target architecture to build the shared library for. Possible values are "default", "x86_64", "arm64".
#   #3: The directory path of the SDL includes.
#   $4: The file path of the SDL shared library (.dll/.so/.dylib).
# OUTPUT: The built shared library if successful, or nothing upon first failure.

DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ -z $SCRIPTS_DIRECTORY ]]; then
    SCRIPTS_DIRECTORY="$DIRECTORY/ext/scripts"
    git clone "https://github.com/bottlenoselabs/scripts" "$SCRIPTS_DIRECTORY" 2> /dev/null 1> /dev/null || git -C "$SCRIPTS_DIRECTORY" pull 1> /dev/null
fi
. $SCRIPTS_DIRECTORY/utility.sh

if [[ ! -z "$1" ]]; then
    TARGET_BUILD_OS="$1"
else
    TARGET_BUILD_OS="host"
fi

if [[ ! -z "$2" ]]; then
    TARGET_BUILD_ARCH="$2"
else
    TARGET_BUILD_ARCH="default"
fi

SDL_INCLUDE_DIRECTORY_PATH=`get_full_path $3`
if [[ ! -z "$SDL_INCLUDE_DIRECTORY_PATH" ]]; then
    if [[ ! -d "$SDL_INCLUDE_DIRECTORY_PATH" ]]; then
        echo "Error: The SDL includes directory does not exist: '$SDL_INCLUDE_DIRECTORY_PATH'"
        exit 1
    fi
    if [[ ! -f "$3/SDL.h" ]]; then
        echo "Error: The SDL includes directory does not contain a 'SDL.h' file: '$SDL_INCLUDE_DIRECTORY_PATH'"
        exit 1
    fi
    CMAKE_SDL2_INCLUDE_DIRS="-DSDL2_INCLUDE_DIRS=$SDL_INCLUDE_DIRECTORY_PATH"
else
    if [[ -d "$DIRECTORY/ext/SDL" ]]; then
        cd $DIRECTORY/ext/SDL
        git pull
        cd $DIRECTORY
    else
        git clone https://github.com/libsdl-org/SDL $DIRECTORY/ext/SDL
    fi
    HAS_CLONED_SDL=1
    CMAKE_SDL2_INCLUDE_DIRS="-DSDL2_INCLUDE_DIRS=$DIRECTORY/ext/SDL/include"
fi

SDL_LIBRARY_FILE_PATH=`get_full_path $4`
if [[ ! -z "$SDL_LIBRARY_FILE_PATH" ]]; then
    if [[ ! -f "$SDL_LIBRARY_FILE_PATH" ]]; then
        echo "Error: The SDL shared library file does not exist: '$4'"
        exit 1
    fi
else
    if [[ "$TARGET_BUILD_OS" == "host" ]]; then
        OS="$(get_operating_system)"
    else
        OS="$TARGET_BUILD_OS"
    fi

    if [[ "$OS" == "linux" ]]; then
        SDL_LIBRARY_FILE_PATH="$DIRECTORY/lib/libSDL2.so"
    elif [[ "$OS" == "macos" ]]; then
        SDL_LIBRARY_FILE_PATH="$DIRECTORY/lib/libSDL2.dylib"
    elif [[ "$OS" == "windows" ]]; then
        SDL_LIBRARY_FILE_PATH="$DIRECTORY/lib/SDL2.lib"
    else
        echo "Unknown OS: '$OS'"
        exit 1
    fi

    SDL_LIBRARY_FILENAME_PINVOKE="SDL2"
    if [[ "$OS" == "windows" ]]; then
        SDL_LIBRARY_FILENAME="SDL2"
    else 
        SDL_LIBRARY_FILENAME="SDL2-2.0"
    fi

    $SCRIPTS_DIRECTORY/c/library/main.sh \
        $DIRECTORY/ext/SDL \
        $DIRECTORY/build \
        $DIRECTORY/lib \
        $SDL_LIBRARY_FILENAME \
        $SDL_LIBRARY_FILENAME_PINVOKE \
        $TARGET_BUILD_OS \
        $TARGET_BUILD_ARCH \
        "-DSDL_STATIC=OFF" "-DSDL_TEST=OFF" "-DSDL_LEAN_AND_MEAN=1" "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.9"
fi
CMAKE_SDL2_LIBRARIES="-DSDL2_LIBRARIES=$SDL_LIBRARY_FILE_PATH"

$SCRIPTS_DIRECTORY/c/library/main.sh \
    $DIRECTORY/ext/FAudio \
    $DIRECTORY/build \
    $DIRECTORY/lib \
    "FAudio" \
    "FAudio" \
    $TARGET_BUILD_OS \
    $TARGET_BUILD_ARCH \
    $CMAKE_SDL2_INCLUDE_DIRS $CMAKE_SDL2_LIBRARIES "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.9"