#!/bin/bash

set -euo pipefail

check(){
	nextversion="$1"
	echo "Checking for next patch: $nextversion"

	if wget -O /tmp/go.tgz "https://golang.org/dl/go$nextversion.linux-amd64.tar.gz"; then
		sha="$(sha256sum /tmp/go.tgz)"
		rm /tmp/go.tgz
		sha="${sha%% *}"
		echo "sha: [$sha]"
		git mv "Dockerfile.$version" "Dockerfile.$nextversion"
		sed -i "s/GOLANG_VERSION=.[0-9.]*/GOLANG_VERSION=$nextversion/;s/DIGEST='.*'/DIGEST='$sha'/" Dockerfile.$nextversion
		git add "Dockerfile.$nextversion"
	fi
}

version="$(ls Dockerfile.* | grep -v 1.10.8)"
version="${version#Dockerfile.}"
major="${version%%.*}"
minor="${version#*.}"
minor="${minor%.*}"
patch="${version##*.}"
if [ "$patch" = "${version#*.}" ]; then
	patch="0"
fi

echo "Current major: $major minor: $minor patch: $patch"

check "$major.$minor.$(( $patch+1 ))"
check "$major.$(( $minor+1 ))"
check "$(( $major+1 ))"
