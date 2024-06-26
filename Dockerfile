# syntax=docker/dockerfile-upstream:master-labs

# Base emsdk image with environment variables.
FROM emscripten/emsdk:3.1.40 AS emsdk-base
ARG EXTRA_CFLAGS
ARG EXTRA_LDFLAGS
ENV INSTALL_DIR=/opt

ENV FFMPEG_VERSION=n7.0.1
ENV CFLAGS="-I$INSTALL_DIR/include $CFLAGS $EXTRA_CFLAGS"
ENV CXXFLAGS="$CFLAGS"
ENV LDFLAGS="-L$INSTALL_DIR/lib $LDFLAGS $CFLAGS $EXTRA_LDFLAGS"
ENV EM_PKG_CONFIG_PATH=$EM_PKG_CONFIG_PATH:$INSTALL_DIR/lib/pkgconfig:/emsdk/upstream/emscripten/system/lib/pkgconfig
ENV EM_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
ENV PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$EM_PKG_CONFIG_PATH
RUN apt-get update && \
      apt-get install -y pkg-config autoconf automake libtool ragel

# Build x264
FROM emsdk-base AS x264-builder
COPY patches/x264/ /patches
COPY build/x264.sh /build.sh
RUN bash -x /build.sh

# Build x265
FROM emsdk-base AS x265-builder
ADD https://github.com/videolan/x265.git#3.4 /src
COPY build/x265.sh /src/build.sh
RUN bash -x /src/build.sh

# Build libvpx
FROM emsdk-base AS libvpx-builder
ADD https://chromium.googlesource.com/webm/libvpx.git#v1.14.1 /src/
COPY build/libvpx.sh /src/build.sh
RUN bash -x /src/build.sh

# Build lame
FROM emsdk-base AS lame-builder
ENV LAME_BRANCH=master
ADD https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download /src/lame.tar.gz
COPY build/lame.sh /src/build.sh
RUN bash -x /src/build.sh

# Build ogg
FROM emsdk-base AS ogg-builder
ADD https://gitlab.xiph.org/xiph/ogg.git#v1.3.4 /src
COPY build/ogg.sh /src/build.sh
RUN bash -x /src/build.sh

# Build theora
FROM emsdk-base AS theora-builder
COPY --from=ogg-builder $INSTALL_DIR $INSTALL_DIR
ADD https://gitlab.xiph.org/xiph/theora.git#v1.1.1 /src
COPY build/theora.sh /src/build.sh
RUN bash -x /src/build.sh

# Build opus
FROM emsdk-base AS opus-builder
ADD https://github.com/xiph/opus.git#v1.3.1 /src
COPY build/opus.sh /src/build.sh
RUN bash -x /src/build.sh

# Build vorbis
FROM emsdk-base AS vorbis-builder
COPY --from=ogg-builder $INSTALL_DIR $INSTALL_DIR
ADD https://gitlab.xiph.org/xiph/vorbis.git#v1.3.3 /src
COPY build/vorbis.sh /src/build.sh
RUN bash -x /src/build.sh

# Build zlib
FROM emsdk-base AS zlib-builder
ADD https://github.com/madler/zlib.git#v1.3.1 /src
COPY build/zlib.sh /src/build.sh
RUN bash -x /src/build.sh

# Build libwebp
FROM emsdk-base AS libwebp-builder
COPY --from=zlib-builder $INSTALL_DIR $INSTALL_DIR
ADD https://github.com/webmproject/libwebp.git#v1.4.0 /src
COPY build/libwebp.sh /src/build.sh
RUN bash -x /src/build.sh

# Build freetype2
FROM emsdk-base AS freetype2-builder
ADD https://git.savannah.gnu.org/git/freetype/freetype2.git#VER-2-13-2 /src
COPY build/freetype2.sh /src/build.sh
RUN bash -x /src/build.sh

# Build fribidi
FROM emsdk-base AS fribidi-builder
ADD https://github.com/fribidi/fribidi.git#v1.0.15 /src
COPY build/fribidi.sh /src/build.sh
RUN bash -x /src/build.sh

# Build harfbuzz
FROM emsdk-base AS harfbuzz-builder
ADD https://github.com/harfbuzz/harfbuzz.git#8.5.0 /src
COPY build/harfbuzz.sh /src/build.sh
RUN bash -x /src/build.sh

# Build libass
FROM emsdk-base AS libass-builder
COPY --from=freetype2-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=fribidi-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=harfbuzz-builder $INSTALL_DIR $INSTALL_DIR
ADD https://github.com/libass/libass.git#0.17.2 /src
COPY build/libass.sh /src/build.sh
RUN bash -x /src/build.sh

# Build zimg
FROM emsdk-base AS zimg-builder
RUN apt-get update && apt-get install -y git
RUN git clone --recursive -b release-3.0.5 https://github.com/sekrit-twc/zimg.git /src
COPY build/zimg.sh /src/build.sh
RUN bash -x /src/build.sh

# Base ffmpeg image with dependencies and source code populated.
FROM emsdk-base AS ffmpeg-base
RUN embuilder build sdl2 sdl2-mt
ADD https://github.com/FFmpeg/FFmpeg.git#$FFMPEG_VERSION /src
COPY --from=x264-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=x265-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=libvpx-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=lame-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=opus-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=theora-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=vorbis-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=libwebp-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=libass-builder $INSTALL_DIR $INSTALL_DIR
COPY --from=zimg-builder $INSTALL_DIR $INSTALL_DIR

# Build ffmpeg
FROM ffmpeg-base AS ffmpeg-builder
COPY build/ffmpeg.sh /src/build.sh
RUN bash -x /src/build.sh \
      --enable-gpl \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libvpx \
      --enable-libmp3lame \
      --enable-libtheora \
      --enable-libvorbis \
      --enable-libopus \
      --enable-zlib \
      --enable-libwebp \
      --enable-libfreetype \
      --enable-libfribidi \
      --enable-libass \
      --enable-libzimg 

# Build ffmpeg.wasm
FROM ffmpeg-builder AS ffmpeg-wasm-builder
COPY src/bind /src/src/bind
COPY src/fftools /src/src/fftools
COPY build/ffmpeg-wasm.sh build.sh
# libraries to link
ENV FFMPEG_LIBS \
      -lx264 \
      -lx265 \
      -lvpx \
      -lmp3lame \
      -logg \
      -ltheora \
      -lvorbis \
      -lvorbisenc \
      -lvorbisfile \
      -lopus \
      -lz \
      -lwebpmux \
      -lwebp \
      -lsharpyuv \
      -lfreetype \
      -lfribidi \
      -lharfbuzz \
      -lass \
      -lzimg
RUN mkdir -p /src/dist/umd && bash -x /src/build.sh \
      ${FFMPEG_LIBS} \
      -o dist/umd/ffmpeg-core.js
RUN mkdir -p /src/dist/esm && bash -x /src/build.sh \
      ${FFMPEG_LIBS} \
      -sEXPORT_ES6 \
      -o dist/esm/ffmpeg-core.js

# Export ffmpeg-core.wasm to dist/, use `docker buildx build -o . .` to get assets
FROM scratch AS exportor
COPY --from=ffmpeg-wasm-builder /src/dist /dist
