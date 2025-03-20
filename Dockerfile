ARG GOLANG_VERSION=1.24.1
ARG ALPINE_VERSION=3.21
FROM golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} AS builder

LABEL maintainer="Yuriy Gorbachev <yuriy@gorbachev.rocks>"

#----------------------------------------------------------------------------------------------------------------------#
# DEPENCIES VERSION
#----------------------------------------------------------------------------------------------------------------------#

ARG MOZJPEG_VERSION=4.1.1
ARG SPNG_VERSION=0.7.4
ARG TIFF_VERSION=4.7.0
ARG ZOPFLI_VERSION=1.0.3
ARG LCMS2_VERSION=2.17
ARG CGIF_VERSION=0.5.0
ARG IMAGEMAGICK_VERSION=7.1.1-45
ARG VIPS_VERSION=8.16.1

ARG LIBDE265_VERSION=1.0.15
ARG DAV1D_VERSION=1.5.0
ARG RAV1E_VERSION=0.7.1
ARG LIBHEIF_VERSION=1.19.7

#----------------------------------------------------------------------------------------------------------------------#
# BUILD DEPENCIES
#----------------------------------------------------------------------------------------------------------------------#

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories

RUN apk update && apk upgrade
RUN apk add libffi zlib zlib-static glib expat libxml2 libexif libpng libpng-static libwebp xz fftw libgsf orc giflib libimagequant highway

RUN apk add --virtual build-depencies pkgconfig libtool git \
    zlib-dev glib-dev expat-dev libxml2-dev libexif-dev libpng-dev libwebp-dev xz-dev fftw-dev libgsf-dev orc-dev giflib-dev libimagequant-dev \
    build-base make nasm cmake meson curl \
    gcc libc-dev glib-dev highway-dev cargo cargo-c

ARG DEPS_PATH=/tmp/deps
RUN mkdir ${DEPS_PATH}

# MOZJPEG
RUN set -x -o pipefail \
    && wget -O- https://github.com/mozilla/mozjpeg/archive/refs/tags/v${MOZJPEG_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/mozjpeg-${MOZJPEG_VERSION} \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib .. \
    && make \
    && make install

# SPNG
RUN set -x -o pipefail \
    && wget -O- https://github.com/randy408/libspng/archive/refs/tags/v${SPNG_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/libspng-${SPNG_VERSION} \
    && meson build --buildtype=release \
    && cd build \
    && ninja \
    && ninja install

# TIFF
RUN set -x -o pipefail \
    && wget -O- https://gitlab.com/libtiff/libtiff/-/archive/v${TIFF_VERSION}/libtiff-v${TIFF_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/libtiff-v${TIFF_VERSION} \
    && cmake . \
    && make \
    && make install

# ZOPFLI
RUN set -x -o pipefail \
    && wget -O- https://github.com/google/zopfli/archive/zopfli-${ZOPFLI_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/zopfli-zopfli-${ZOPFLI_VERSION} \
    && make zopflipng \
    && cp ./zopflipng /usr/bin/

# LCMS
RUN set -x -o pipefail \
    && wget -O- https://sourceforge.net/projects/lcms/files/lcms/${LCMS2_VERSION}/lcms2-${LCMS2_VERSION}.tar.gz/download | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/lcms2-${LCMS2_VERSION} \
    && ./configure \
         --host=$HOST \
         --prefix=/usr/local \
         --enable-shared \
         --disable-static \
         --disable-dependency-tracking \
    && make install-strip

# CGIF
RUN set -x -o pipefail \
    && wget -O- https://github.com/dloebl/cgif/archive/refs/tags/v${CGIF_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/cgif-${CGIF_VERSION} \
    && meson setup --prefix=/usr/local build \
    && meson install -C build

# LIBDE265
RUN set -x -o pipefail \
    && wget -O- https://github.com/strukturag/libde265/releases/download/v${LIBDE265_VERSION}/libde265-${LIBDE265_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/libde265-${LIBDE265_VERSION} \
    && ./configure --prefix=/usr/local --enable-shared --disable-static \
    && make install-strip

# DAV1D
RUN set -x -o pipefail \
    && wget -O- https://code.videolan.org/videolan/dav1d/-/archive/${DAV1D_VERSION}/dav1d-${DAV1D_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/dav1d-${DAV1D_VERSION} \
    && meson setup _build --buildtype=release --strip --prefix=/usr/local --libdir=lib \
    && ninja -C _build \
    && ninja -C _build install

# RAV1E
RUN set -x -o pipefail \
    && wget -O- https://github.com/xiph/rav1e/archive/refs/tags/v${RAV1E_VERSION}/.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/rav1e-${RAV1E_VERSION} \
    && cargo cinstall --release

# HEIF
RUN set -x -o pipefail \
    && wget -O- https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/libheif-${LIBHEIF_VERSION} \
    && mkdir _build \
    && cd _build \
    && cmake --preset=release .. \
    && make \
    && make install

# IMAGEMAGICK
RUN set -x -o pipefail \
    && wget -O- https://github.com/ImageMagick/ImageMagick/archive/refs/tags/${IMAGEMAGICK_VERSION}.tar.gz | tar xzC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/ImageMagick-${IMAGEMAGICK_VERSION} \
    && ./configure \
      --without-magick-plus-plus \
      --without-perl \
      --disable-openmp \
      --with-gvc=no \
      --disable-docs \
    && make -j$(nproc) \
    && make install \
    && ldconfig /usr/local/lib

# LIBVIPS
RUN set -x -o pipefail \
    && wget -O- https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz | tar xJC ${DEPS_PATH} \
    && cd ${DEPS_PATH}/vips-${VIPS_VERSION} \
    && meson setup build \
       --prefix=/usr/local \
       --libdir=lib \
       --buildtype release \
       -Dintrospection=disabled \
       -Dcplusplus=true \
       -Dppm=false \
       -Danalyze=false \
       -Dradiance=false \
    && cd build \
    && meson compile \
    && meson install

#----------------------------------------------------------------------------------------------------------------------#

WORKDIR /go