#!/bin/bash

set -euo pipefail

cd /src
echo "ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e  lame.tar.gz" \
     | sha256sum --check --status
tar xvzf lame.tar.gz --strip-components=1

CONF_FLAGS=(
  --prefix=$INSTALL_DIR                               # install library in a build directory for FFmpeg to include
  --host=i686-linux                                   # use i686 linux
  --disable-shared                                    # disable shared library
  --disable-frontend                                  # exclude lame executable
  --disable-analyzer-hooks                            # exclude analyzer hooks
  --disable-dependency-tracking                       # speed up one-time build
  --disable-gtktest
)
CFLAGS=$CFLAGS emconfigure ./configure "${CONF_FLAGS[@]}"
emmake make install -j
