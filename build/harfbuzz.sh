#!/bin/bash

set -euo pipefail

CFLAGS="$CFLAGS -DHB_NO_PRAGMA_GCC_DIAGNOSTIC_ERROR"

sed -i 's#\[have_pthread=false\]#\[have_pthread=true\]#g' configure.ac
CXXFLAGS=$CFLAGS
CONF_FLAGS=(
  --prefix=$INSTALL_DIR                                 # install library in a build directory for FFmpeg to include
  --host=i686-gnu                                     # use i686 linux
  --enable-shared=no                                  # not to build shared library
  --enable-static 
)

emconfigure ./autogen.sh "${CONF_FLAGS[@]}"
emmake make install -j
