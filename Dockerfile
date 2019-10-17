FROM debian:stretch

SHELL ["/bin/bash", "-uec"]

# Setup arm builder, windows, and OS X
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt install -y build-essential libssl-dev \
    libc6-dev-i386 libc6-dev:i386 lib32gcc-6-dev \
    gcc-6-arm-linux-gnueabi g++-6-arm-linux-gnueabi \
    gcc-6-aarch64-linux-gnu g++-6-aarch64-linux-gnu \
    mingw-w64 \
    clang \
    m4 file \
    wget git \
 && apt clean \
 && rm -rf /var/lib/apt/lists

# Setup musl
RUN wget http://www.musl-libc.org/releases/musl-latest.tar.gz \
 && tar -zxvf musl-latest.tar.gz \
 && rm musl-latest.tar.gz \
 && cd musl* \
 && ./configure --prefix=/usr/local/musl-x86_64 -exec-prefix=/usr/local/musl-x86_64 \
 && make -j$(nproc) \
 && make install \
 && make clean \
 && export CC=arm-linux-gnueabi-gcc-6 \
 && ./configure --prefix=/usr/local/musl-arm -exec-prefix=/usr/local/musl-arm \
 && make -j$(nproc) \
 && make install \
 && make clean \
 && export CC=aarch64-linux-gnu-gcc-6 \
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
 && git clone https://github.com/tpoechtrager/osxcross.git /osxcross \
 && (cd /osxcross && git checkout 9498bfdc621716959e575bd6779c853a03cf5f8d && git reset --hard ) \
 && mv `basename $OSX_SDK_PATH` /osxcross/tarballs/ \
 && sed -i -e 's|-march=native||g' /osxcross/build_clang.sh /osxcross/wrapper/build.sh \
 && UNATTENDED=yes OSX_VERSION_MIN=10.6 /osxcross/build.sh \
 && mv /osxcross/target $OSX_NDK_X86 \
 && rm -rf /osxcross

RUN wget https://github.com/karalabe/xgo/blob/master/docker/base/patch.tar.xz?raw=true -O patch.tar.xz \
 && tar -xf patch.tar.xz -C $OSX_NDK_X86/SDK/$OSX_SDK/usr/include/c++ \
 && rm patch.tar.xz

# Setup Freebsd, stolen from https://github.com/sandvine/freebsd-cross-build
RUN mkdir -p /freebsd/x86_64-pc-freebsd10 && cd /freebsd \
 && wget ftp://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/amd64/amd64/10.1-RELEASE/base.txz \
 && wget ftp://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/amd64/amd64/10.1-RELEASE/lib32.txz \
 && tar -xf base.txz ./usr/lib \
 && tar -xf base.txz ./usr/include \
 && tar -xf base.txz ./lib \
 && rm base.txz \
 && tar -xf lib32.txz ./usr/lib32 \
 && rm lib32.txz \
 && mv usr/include x86_64-pc-freebsd10 \
 && mv usr/lib x86_64-pc-freebsd10 \
 && mv lib/* x86_64-pc-freebsd10/lib/ \
 && mv usr/lib32 x86_64-pc-freebsd10/ \
 && rmdir lib usr \
 && cd x86_64-pc-freebsd10/lib \
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
 && tar -xf binutils*.tar.gz \
 && rm binutils*.tar.gz \
 && pushd binutils* \
 && ./configure --enable-libssp --enable-ld --target=x86_64-pc-freebsd10 --prefix=/freebsd \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf binutils*
RUN wget http://ftp.gnu.org/gnu/gmp/gmp-6.0.0a.tar.xz \
 && tar -xf gmp*.tar.xz \
 && rm gmp*.tar.xz \
 && pushd gmp* \
 && ./configure --prefix=/freebsd --enable-shared --enable-static --enable-fft \
    --enable-cxx --host=x86_64-pc-freebsd10 \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf gmp*
RUN wget http://ftp.gnu.org/gnu/mpfr/mpfr-3.1.3.tar.xz \
 && tar -xf mpfr*.tar.xz \
 && rm mpfr*.tar.xz \
 && pushd mpfr* \
 && ./configure --prefix=/freebsd --with-gnu-ld --enable-static --enable-shared \
    --with-gmp=/freebsd --host=x86_64-pc-freebsd10 \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf mpfr*
RUN wget http://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz \
 && tar -xf mpc*.tar.gz \
 && rm mpc*.tar.gz \
 && pushd mpc* \
 && ./configure --prefix=/freebsd --with-gnu-ld --enable-static --enable-shared \
    --with-gmp=/freebsd --with-mpfr=/freebsd --host=x86_64-pc-freebsd10 \
 && make -j$(nproc) \
 && make install \
 && popd \
 && rm -rf mpc*
RUN wget http://ftp.gnu.org/gnu/gcc/gcc-6.3.0/gcc-6.3.0.tar.bz2 \
 && tar -xf gcc*.tar.bz2 \
 && rm gcc*.tar.bz2 \
 && pushd gcc* \
 && mkdir build \
 && cd build \
 && ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
    --enable-languages=c,c++ --enable-libssp --enable-ld --disable-libitm \
    --disable-libquadmath --target=x86_64-pc-freebsd10 --prefix=/freebsd \
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
