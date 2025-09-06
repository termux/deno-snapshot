#!/usr/bin/env bash
set -e -u -o pipefail

_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)
source $_SCRIPTDIR/common-files/termux_download.sh

: ${HOST_ARCH:=x86_64}
: ${_CACHE_DIR:=$_SCRIPTDIR/cache}
: ${_TMP_DIR:=$_SCRIPTDIR/tmp}
: ${_BUILD_DIR:=$_SCRIPTDIR/build}

DENO_VERSION="2.4.5"
DENO_SHA256SUM="a6bba626d08813c114bfcc862e69fd7202eecda97df9f349abf6cc4e38fe4e40"

__prepare_env() {
	sudo apt update
	sudo apt install cmake -y

	export OVERRIDE_TARGET="$HOST_ARCH-linux-android"
	mkdir -p $_CACHE_DIR
	mkdir -p $_TMP_DIR
	mkdir -p $_BUILD_DIR/$OVERRIDE_TARGET
	rm -rf $_TMP_DIR/*
}

__bootstrap_rust() {
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	. "$HOME/.cargo/env"
}

__fetch_deno_source() {
	TERMUX_PKG_TMPDIR=$_TMP_DIR termux_download \
		https://github.com/denoland/deno/releases/download/v$DENO_VERSION/deno_src.tar.gz \
		$_CACHE_DIR/deno_src_$DENO_VERSION.tar.gz \
		$DENO_SHA256SUM
	rm -rf $_TMP_DIR/deno-src-$DENO_VERSION
	mkdir -p $_TMP_DIR/deno-src-$DENO_VERSION
	tar -xf $_CACHE_DIR/deno_src_$DENO_VERSION.tar.gz \
		-C $_TMP_DIR/deno-src-$DENO_VERSION \
		--strip-components=1
}

__apply_patches() {
	local f
	for f in $(find "$_SCRIPTDIR/patches/" -maxdepth 1 -type f -name *.patch | sort); do
		echo "Applying patch: $(basename $f)"
		patch -d "$_TMP_DIR/deno-src-$DENO_VERSION/" -p1 < "$f";
	done
}

__build_snaphost() {
	cd "$_TMP_DIR/deno-src-$DENO_VERSION/"
	cargo build --release --lib --manifest-path ./cli/snapshot/Cargo.toml
	find ./target -type f -name "*SNAPSHOT.bin" -exec cp '{}' $_BUILD_DIR/$OVERRIDE_TARGET \;
	cd -
}

__package_snapshot() {
	cd "$_BUILD_DIR"
	tar -cjvf deno-snapshot-$OVERRIDE_TARGET-$DENO_VERSION.tar.bz2 $OVERRIDE_TARGET
	rm -rf $OVERRIDE_TARGET
	cd -
}

__prepare_env
__bootstrap_rust
__fetch_deno_source
__apply_patches
__build_snaphost
__package_snapshot
