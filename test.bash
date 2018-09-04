#!/bin/bash
set -u

test-onbuild(){
	cd "test-$cgo" || exit 1
	docker build --build-arg "IMAGE_NAME=${IMAGE_NAME}" -t "golang-test-$cgo-onbuild" .
	docker run --rm -i "golang-test-$cgo-onbuild" | grep '^it works$'
}

test-tar(){
	CGO=0
	if [ "$cgo" == "cgo" ]; then
		CGO="1"
	fi
	EXT=""
	if [ "$os" = "windows" ]; then
		EXT=".exe"
	fi
	o="$(tar -cC "test-$cgo" . | docker run --rm -i \
		-e TAR=1 -e VERBOSE=1 -e "GOOS=$os" -e "GOARCH=$arch" -e "CGO_ENABLED=$CGO" \
		"${IMAGE_NAME}" | tar -x "./app${EXT}" -O | file -)"
	echo "$o"
	grep -q -E "$1" <<< "$o"
}

display-results(){
	if [ -n "${FAILURES:-}" ]; then
		if [ "$ret" != 0 ]; then
			echo "### $arch $os $cgo $ret"
			echo "$o"
			echo
			echo
		fi
	else
		sym="F "
		if [ "$ret" = 0 ]; then
			sym="✓ "
		fi
		printf "%s\\t%s\\t%s\\t%s\\t%d\\n" "$sym" "$arch" "$os" "$cgo"
		echo "$o" > "${arch}_${os}_${cgo}.results"
	fi
}

declare -A outputs
outputs=(
	[amd64_linux]="ELF.*x86-64.*static"
	[386_linux]="ELF.*386.*static"
	[arm_linux]="ELF.*ARM,*static"
	[386_darwin]="Mach-O i386"
	[amd64_darwin]="Mach-O 64"
	[386_windows]="PE32[^+]"
	[amd64_windows]="PE32\\+"
	[amd64_freebsd]="x86-64.*FreeBSD.*static"
	[386_freebsd]="80386.*FreeBSD.*static"
	[386_onbuild]=""
	[amd64_onbuild]=""
)

IMAGE_NAME="${IMAGE_NAME:-brimstone/golang:latest}"

rm -f ./*.results
for output in $(echo "${!outputs[@]}" | tr ' ' '\n' | sort); do
	if [ -n "${1:-}" ]; then
		if ! grep -qE "$1" <<< "$output"; then
			continue
		fi
	fi
	IFS=_ read -r arch os <<< "$output"
	for cgo in cgo nocgo; do
		if [ "$os" = "onbuild" ]; then
			o="$(test-onbuild 2>&1)"
		else
			o="$(test-tar "${outputs[$output]}" 2>&1)"
		fi
		ret=$?
		display-results
	done
done
