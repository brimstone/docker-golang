FROM debian:buster

SHELL ["/bin/bash", "-uec"]

# Setup arm builder, windows, and OS X
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt install -y build-essential libssl-dev \
    libc6-dev-i386 libc6-dev:i386 lib32gcc-8-dev \
    gcc-8-arm-linux-gnueabi g++-8-arm-linux-gnueabi \
    gcc-8-aarch64-linux-gnu g++-8-aarch64-linux-gnu \
    mingw-w64 \
    clang \
    m4 file \
    wget git \
    brotli \
 && apt clean \
 && rm -rf /var/lib/apt/lists

# Setup musl
RUN wget https://www.musl-libc.org/releases/musl-1.2.3.tar.gz \
 && echo "7d5b0b6062521e4627e099e4c9dc8248d32a30285e959b7eecaa780cf8cfd4a4 musl-1.2.3.tar.gz" | sha256sum -c - \
 && tar -zxvf musl-1.2.3.tar.gz \
 && rm musl-1.2.3.tar.gz \
 && cd musl* \
 && ./configure --prefix=/usr/local/musl-x86_64 -exec-prefix=/usr/local/musl-x86_64 \
 && make -j$(nproc) \
 && make install \
 && make clean \
 && export CC=arm-linux-gnueabi-gcc-8 \
 && ./configure --prefix=/usr/local/musl-arm -exec-prefix=/usr/local/musl-arm \
 && make -j$(nproc) \
 && make install \
 && make clean \
 && export CC=aarch64-linux-gnu-gcc-8 \
 && ./configure --prefix=/usr/local/musl-aarch64 -exec-prefix=/usr/local/musl-aarch64 \
 && make -j$(nproc) \
 && make install \
 && make clean \
 && cd .. \
 && rm -rf musl*

# TODO remove .sdk file?
# Stolen from https://github.com/karalabe/xgo/blob/master/docker/base/Dockerfile
ENV OSX_SDK=MacOSX10.11.sdk
ENV OSX_NDK_X86 /usr/local/osx-ndk-x86
RUN OSX_SDK_PATH=https://s3.dockerproject.org/darwin/v2/$OSX_SDK.tar.xz \
 && wget $OSX_SDK_PATH \
 && echo "694a66095a3514328e970b14978dc78c0f4d170e590fa7b2c3d3674b75f0b713 ${OSX_SDK}.tar.xz" | sha256sum -c - \
 && git clone https://github.com/tpoechtrager/osxcross.git /osxcross \
 && (cd /osxcross && git checkout 9498bfdc621716959e575bd6779c853a03cf5f8d && git reset --hard ) \
 && mv `basename $OSX_SDK_PATH` /osxcross/tarballs/ \
 && sed -i -e 's|-march=native||g' /osxcross/build_clang.sh /osxcross/wrapper/build.sh \
 && UNATTENDED=yes OSX_VERSION_MIN=10.6 /osxcross/build.sh \
 && mv /osxcross/target $OSX_NDK_X86 \
 && rm -rf /osxcross

RUN wget https://github.com/karalabe/xgo/blob/master/docker/base/patch.tar.xz?raw=true -O patch.tar.xz \
 && echo "199d8fa4523c248d1ee49bf300da031e6a56aab5ec7261927e0a8bdfe0737bf4 patch.tar.xz" | sha256sum -c - \
 && tar -xf patch.tar.xz -C $OSX_NDK_X86/SDK/$OSX_SDK/usr/include/c++ \
 && rm patch.tar.xz

# Setup Freebsd, stolen from https://github.com/sandvine/freebsd-cross-build
RUN mkdir -p /freebsd/x86_64-pc-freebsd12 && cd /freebsd \
 && wget http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/amd64/12.3-RELEASE/base.txz \
 && echo "e85b256930a2fbc04b80334106afecba0f11e52e32ffa197a88d7319cf059840 base.txz" | sha256sum -c - \
 && wget http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/amd64/12.3-RELEASE/lib32.txz \
 && echo "8d7425ddbbf7b99fad26f439723eaf80df6509cc2d70f871d5bbb6e721055323 lib32.txz" | sha256sum -c - \
 && tar -xf base.txz ./usr/lib \
 && tar -xf base.txz ./usr/include \
 && tar -xf base.txz ./lib \
 && rm base.txz \
 && tar -xf lib32.txz ./usr/lib32 \
 && rm lib32.txz \
 && mv usr/include x86_64-pc-freebsd12 \
 && mv usr/lib x86_64-pc-freebsd12 \
 && mv lib/* x86_64-pc-freebsd12/lib/ \
 && mv usr/lib32 x86_64-pc-freebsd12/ \
 && rmdir lib usr \
 && cd x86_64-pc-freebsd12/lib \
 && ln -sf libc.so.7 libc.so \
 && ln -sf libc++.so.1 libc++.so \
 && cd ../lib32 \
 && ln -sf libc.so.7 libc.so \
 && ln -sf libc++.so.1 libc++.so \
 && cd .. \
 && find lib lib32 -type l \
    | while read -r alink; do \
        ln -fs "$(basename $(readlink "$alink"))" "$alink"; \
      done
RUN wget http://ftp.gnu.org/gnu/binutils/binutils-2.25.1.tar.gz \
 && echo "82a40a37b13a12facb36ac7e87846475a1d80f2e63467b1b8d63ec8b6a2b63fc binutils-2.25.1.tar.gz" | sha256sum -c - \
 && tar -xf binutils*.tar.gz \
 && rm binutils*.tar.gz \
 && pushd binutils* \
 && ./configure --enable-libssp --enable-ld --target=x86_64-pc-freebsd12 --prefix=/freebsd \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf binutils*
RUN wget http://ftp.gnu.org/gnu/gmp/gmp-6.0.0a.tar.xz \
 && echo "9156d32edac6955bc53b0218f5f3763facb890b73a835d5e1b901dcf8eb8b764 gmp-6.0.0a.tar.xz" | sha256sum -c - \
 && tar -xf gmp*.tar.xz \
 && rm gmp*.tar.xz \
 && pushd gmp* \
 && ./configure --prefix=/freebsd --enable-shared --enable-static --enable-fft \
    --enable-cxx --host=x86_64-pc-freebsd12 \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf gmp*
RUN wget http://ftp.gnu.org/gnu/mpfr/mpfr-3.1.3.tar.xz \
 && echo "6835a08bd992c8257641791e9a6a2b35b02336c8de26d0a8577953747e514a16 mpfr-3.1.3.tar.xz" | sha256sum -c - \
 && tar -xf mpfr*.tar.xz \
 && rm mpfr*.tar.xz \
 && pushd mpfr* \
 && ./configure --prefix=/freebsd --with-gnu-ld --enable-static --enable-shared \
    --with-gmp=/freebsd --host=x86_64-pc-freebsd12 \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf mpfr*
RUN wget http://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz \
 && echo "617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3 mpc-1.0.3.tar.gz" | sha256sum -c - \
 && tar -xf mpc*.tar.gz \
 && rm mpc*.tar.gz \
 && pushd mpc* \
 && ./configure --prefix=/freebsd --with-gnu-ld --enable-static --enable-shared \
    --with-gmp=/freebsd --with-mpfr=/freebsd --host=x86_64-pc-freebsd12 \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf mpc*
RUN wget https://ftp.gnu.org/gnu/gcc/gcc-8.1.0/gcc-8.1.0.tar.gz \
 && echo "af300723841062db6ae24e38e61aaf4fbf3f6e5d9fd3bf60ebbdbf95db4e9f09 gcc-8.1.0.tar.gz" | sha256sum -c - \
 && tar -xf gcc*.tar.gz \
 && rm gcc*.tar.gz \
 && pushd gcc* \
 && mkdir build \
 && cd build \
 && ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
    --enable-languages=c,c++ --enable-libssp --enable-ld --disable-libitm \
    --disable-libquadmath --target=x86_64-pc-freebsd12 --prefix=/freebsd \
    --with-gmp=/freebsd --with-mpc=/freebsd --with-mpfr=/freebsd --disable-libgomp \
 && LD_LIBRARY_PATH=/freebsd/lib make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf gcc*

ENV CC=/bin/cc \
	CGO_ENABLED=1 \
	CXX=/bin/c++ \
	GOPATH=/go \
	HOME=/tmp \
	PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/osx-ndk-x86/bin:/freebsd/bin:/usr/local/go/bin:/go/bin \
    GOOS="linux" \
    LDFLAGS="" \
	TAR="" \
    VERBOSE=""

COPY loader /loader

COPY cc /bin/cc

RUN ln -s /bin/cc /bin/c++ \
 && ln -s /bin/cc /bin/go \
 && mkdir -p "$GOPATH/src" "$GOPATH/bin" \
 && chmod -R 777 "$GOPATH"

WORKDIR /go/src/app

ENTRYPOINT [ "/loader" ]

ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/brimstone/docker-golang" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1"
