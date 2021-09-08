#!/bin/bash
set -u

test-onbuild(){
	cd "test-$cgo" || exit 1
	docker build --build-arg "IMAGE_NAME=${IMAGE_NAME}" -t "golang-test-$cgo-onbuild" . || exit 1
	docker run --rm -i "golang-test-$cgo-onbuild" | grep '^it works$' || exit 1
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
	tar -cC "test-$cgo" . | docker run --rm -i \
		-e TAR=1 -e VERBOSE=1 -e "GOOS=$os" -e "GOARCH=$arch" -e "CGO_ENABLED=$CGO" \
		"${IMAGE_NAME}" | tar -x "./test-${cgo}${EXT}" -O > output
	o="$(file output)"
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
		printf "%s\\t%s\\t%s\\t%s\\t%s\\n" "$sym" "$os" "$arch" "$cgo" "$sd"
		echo "$o" > "${os}_${arch}_${cgo}.results"
	fi
}

declare -A outputs
outputs=(
	[linux_amd64]="ELF.*x86-64.*static.*, stripped"
	[linux_386]="ELF.*386.*static.*, stripped"
	[linux_arm]="ELF.*ARM.*EABI5.*static.*, stripped"
	[linux_arm64]="ELF.*ARM.*aarch64.*static.*, stripped"
	[darwin_amd64]="Mach-O 64"
	[darwin_arm64]="Mach-O 64"
	[windows_386]="PE32[^+]"
	[windows_amd64]="PE32\\+"
	[freebsd_amd64]="x86-64.*FreeBSD.*static.*, stripped"
	[onbuild_386]=""
	[onbuild_amd64]=""
)

IMAGE_NAME="${IMAGE_NAME:-storjlabs/golang:latest}"

echo "IMAGE_NAME: ${IMAGE_NAME}"

rm -f ./*.results
for output in $(echo "${!outputs[@]}" | tr ' ' '\n' | sort); do
	if [ -n "${1:-}" ]; then
		if ! grep -qE "$1" <<< "$output"; then
			continue
		fi
	fi
	IFS=_ read -r os arch <<< "$output"
	for cgo in cgo nocgo; do
		if [ "$os" = "onbuild" ]; then
			o="$(test-onbuild 2>&1)"
			ret=$?
			sd="n/a"
		else
			rm -f output
			o="$(test-tar "${outputs[$output]}" 2>&1)"
			ret=$?
			sd="n/a"
			if [ $ret = 0 ]; then
				s1="$(sha1sum "output")"
				test-tar "${outputs[$output]}" >/dev/null 2>/dev/null
				s2="$(sha1sum "output")"
				sd="Non-reproducable"
				if [ "$s1" = "$s2" ]; then
					sd="Reproducable"
				fi
			fi
		fi
		display-results
	done
done
rm -f output
