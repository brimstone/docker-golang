#!/bin/bash
set -ue

GOOS=${GOOS:-linux}
GOARCH=${GOARCH:-amd64}

# If we're not `go build`, abort
if [ "$0" = "/bin/go" ] && [ "$1" != "build" ]; then
	exec /usr/local/go/bin/go "$@"
fi

case "$GOOS-$GOARCH-$(basename "$0")" in
## Linux
linux-arm-cc)
	export CC=arm-linux-gnueabi-gcc-6
	exec "$CC" "$@"
;;
linux-arm-c++)
	export CXX=arm-linux-gnueabi-g++-6
	exec "$CXX" "$@"
;;
linux-386-cc)
	export CC=gcc
	exec "$CC" "$@"
;;
linux-386-c++)
	export CC=g++
	exec "$CC" "$@"
;;
linux-amd64-cc)
	export CC=/usr/local/musl/bin/musl-gcc
	exec "$CC" "$@"
;;
linux-amd64-c++)
	export CXX=g++
	exec "$CXX" "$@"
;;
linux-*-go)
	LDFLAGS="${LDFLAGS:-} -linkmode external -extldflags \"-static\""
;;
## Windows
windows-amd64-cc)
	export CC=x86_64-w64-mingw32-gcc
	exec "${CC}" "$@"
;;
windows-386-cc)
	export CC=i686-w64-mingw32-gcc
	exec "${CC}" "$@"
;;
windows-*-go)
;;
## Darwin
darwin-386-cc)
	export CC=o32-clang
	exec "${CC}" "$@"
;;
darwin-386-c++)
	export CXX=o32-clang++
	exec "${CXX}" "$@"
;;
darwin-amd64-cc)
	export CC=o64-clang
	exec "${CC}" "$@"
;;
darwin-amd64-c++)
	export CXX=o64-clang++
	exec "${CXX}" "$@"
;;
darwin-*-go)
;;
## Freebsd
freebsd-386-cc)
	export LD_LIBRARY_PATH=/freebsd/lib:/freebsd/lib32
	export CC=i386-pc-freebsd10-gcc
	exec "${CC}" "$@"
;;
freebsd-386-c++)
	export LD_LIBRARY_PATH=/freebsd/lib:/freebsd/lib32
	export CXX=i386-pc-freebsd10-gpp
	exec "${CXX}" "$@"
;;
freebsd-amd64-cc)
	export LD_LIBRARY_PATH=/freebsd/lib:/freebsd/lib32
	export CC=x86_64-pc-freebsd10-gcc
	exec "${CC}" "$@"
;;
freebsd-amd64-c++)
	export LD_LIBRARY_PATH=/freebsd/lib:/freebsd/lib32
	# FINDME should this be CPP?
	export CXX=x86_64-pc-freebsd10-gpp
	exec "${CXX}" "$@"
;;
freebsd-*-go)
	LDFLAGS="${LDFLAGS:-} -linkmode external -extldflags \"-static\""
;;
*)
	echo "Why does GOOS=${GOOS} GOARCH=${GOARCH} 0=$0?"
	exit 1
;;
esac

# $0 must be go, or we should have gotten this far
# The first arg should be 'build', or we wouldn't have gotten this far
shift
declare -a arr=()
set_flags=0
while (( $# )); do
	if [ "$1" = "-ldflags" ]; then
		shift
		arr[${#arr[@]}]="-ldflags"
		arr[${#arr[@]}]="$LDFLAGS $1"
		set_flags=1
	else
		arr[${#arr[@]}]=$1
	fi
	shift
done
if [ "$set_flags" = 0 ]; then
	echo /usr/local/go/bin/go build -ldflags "-s -w ${LDFLAGS:-}" "${arr[@]}"
	exec /usr/local/go/bin/go build -ldflags "-s -w ${LDFLAGS:-}" "${arr[@]}"
else
	echo /usr/local/go/bin/go build "${arr[@]}"
	exec /usr/local/go/bin/go build "${arr[@]}"
fi