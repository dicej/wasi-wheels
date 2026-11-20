BUILD_DIR := $(abspath build)
WASI_SDK := $(BUILD_DIR)/wasi-sdk
CPYTHON := $(BUILD_DIR)/cpython
SYSCONFIG := $(BUILD_DIR)/cpython/builddir/wasi/build/lib.wasi-wasm32-3.15
OUTPUTS := $(BUILD_DIR)/numpy-wasi.tar.gz
WASI_SDK_VERSION := 34
HOST_OS := $(shell uname -s | sed -e 's/Darwin/macos/' -e 's/Linux/linux/')
HOST_ARCH := $(shell uname -m | sed -e 's/aarch64/arm64/')
PYO3_CROSS_LIB_DIR := $(abspath cpython/builddir/wasi/build/lib.wasi-wasm32-3.15)

.PHONY: all
all: $(OUTPUTS)

$(OUTPUTS): $(WASI_SDK) $(CPYTHON)

$(BUILD_DIR)/numpy-wasi.tar.gz: $(WASI_SDK) $(CPYTHON)
	@mkdir -p "$(@D)"
	(cd numpy && WASI_SDK_PATH=$(WASI_SDK) CPYTHON_PATH=$(CPYTHON) NUMPY_PATH=$$(pwd) bash build.sh)
	cp -a numpy/src/wasi-build/install/usr/local/lib/python3.15/site-packages/numpy "$(@D)"
	(cd "$(@D)" && tar czf numpy-wasi.tar.gz numpy)

$(WASI_SDK):
	@mkdir -p "$(@D)"
	(cd "$(@D)" && \
		curl -LO https://github.com/dicej/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}-shared-library-exceptions/wasi-sdk-${WASI_SDK_VERSION}.0-shared-library-exceptions-${HOST_ARCH}-${HOST_OS}.tar.gz && \
		tar xf wasi-sdk-${WASI_SDK_VERSION}.0-shared-library-exceptions-${HOST_ARCH}-${HOST_OS}.tar.gz && \
		mv wasi-sdk-${WASI_SDK_VERSION}.0-shared-library-exceptions-${HOST_ARCH}-${HOST_OS} "$@" && \
		rm wasi-sdk-$(WASI_SDK_VERSION).0-shared-library-exceptions-${HOST_ARCH}-${HOST_OS}.tar.gz)

$(CPYTHON): $(WASI_SDK)
	@mkdir -p "$(@D)"
	(cd "$(@D)" && \
		curl -LO https://www.python.org/ftp/python/3.15.2/Python-3.15.2.tgz && \
		tar xf Python-3.15.2.tgz && \
		mv Python-3.15.2 "$@" && \
		rm Python-3.15.2.tgz)
	@mkdir -p "$@/builddir/build"
	(cd "$@/builddir/build" && ../../configure --prefix=$$(pwd)/install && make install)
	@mkdir -p "$@/builddir/wasip3"
	(cd "$@/builddir/wasip3" && \
		WASI_SDK_PATH=$(WASI_SDK) \
		CONFIG_SITE=../../Platforms/WASI/config.site-wasm32-wasi \
		HOSTRUNNER=wasmtime \
		CFLAGS="--target=wasm32-wasip3 -fPIC" \
		LDFLAGS="--target=wasm32-wasip3" \
		../../Tools/wasm/wasi-env \
		../../configure \
		-C \
		--host=wasm32-unknown-wasip2 \
		--build=$$(../../config.guess) \
		--with-build-python=$$(if [ -e $$(pwd)/../build/python.exe ]; \
			then echo $$(pwd)/../build/python.exe; \
			else echo $$(pwd)/../build/python; \
			fi) \
		--prefix=$$(pwd)/install \
		--enable-wasm-dynamic-linking \
		--enable-ipv6 \
		--disable-test-modules \
		--without-system-libmpdec && \
		make build_all install && \
		$(WASI_SDK)/bin/clang \
		--target=wasm32-wasip3 \
		-shared \
		-o $@/builddir/wasip3/install/lib/libpython3.15.so \
		-Wl,--whole-archive $@/builddir/wasip3/install/lib/libpython3.15.a -Wl,--no-whole-archive \
		$@/builddir/wasip3/Modules/_hacl/libHacl_HMAC.a \
		$@/builddir/wasip3/Modules/_hacl/libHacl_Hash_BLAKE2.a \
		$@/builddir/wasip3/Modules/_hacl/libHacl_Hash_MD5.a \
		$@/builddir/wasip3/Modules/_hacl/libHacl_Hash_SHA1.a \
		$@/builddir/wasip3/Modules/_hacl/libHacl_Hash_SHA2.a \
		$@/builddir/wasip3/Modules/_hacl/libHacl_Hash_SHA3.a \
		$@/builddir/wasip3/Modules/_decimal/libmpdec/libmpdec.a \
		$@/builddir/wasip3/Modules/expat/libexpat.a \
		-lwasi-emulated-signal \
		-lwasi-emulated-getpid \
		-lwasi-emulated-process-clocks \
		-ldl)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) numpy/numpy/build

