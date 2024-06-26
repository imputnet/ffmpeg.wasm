#!/bin/bash

set -euo pipefail

git clone https://code.videolan.org/videolan/x264.git /src
cd /src
git checkout 31e19f92f00c
git apply /patches/*

CONF_FLAGS=(
  --prefix=$INSTALL_DIR           # lib installation dir
  --host=x86-gnu                  # use x86 linux host
  --enable-static                 # build static library
  --disable-cli                   # disable cli build
  --disable-asm                   # disable assembly
  --extra-cflags="$CFLAGS"        # add extra cflags
)

emconfigure ./configure "${CONF_FLAGS[@]}"
emmake make install-lib-static -j
