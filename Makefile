BUILD_DIR := $(abspath build)
WASI_SDK := $(BUILD_DIR)/wasi-sdk
CPYTHON := $(abspath cpython/builddir/wasi/install)
SYSCONFIG := $(abspath cpython/builddir/wasi/build/lib.wasi-wasm32-3.11)
OUTPUTS := \
	$(BUILD_DIR)/aiohttp-wasi.tar.gz \
	$(BUILD_DIR)/charset_normalizer-wasi.tar.gz \
	$(BUILD_DIR)/frozenlist-wasi.tar.gz \
	$(BUILD_DIR)/multidict-wasi.tar.gz \
	$(BUILD_DIR)/numpy-wasi.tar.gz \
	$(BUILD_DIR)/pandas-wasi.tar.gz \
	$(BUILD_DIR)/pydantic_core-wasi.tar.gz \
	$(BUILD_DIR)/regex-wasi.tar.gz \
	$(BUILD_DIR)/sqlalchemy-wasi.tar.gz \
	$(BUILD_DIR)/tiktoken-wasi.tar.gz \
	$(BUILD_DIR)/tiktoken_ext-wasi.tar.gz \
	$(BUILD_DIR)/wrapt-wasi.tar.gz \
	$(BUILD_DIR)/yaml-wasi.tar.gz \
	$(BUILD_DIR)/_yaml-wasi.tar.gz \
	$(BUILD_DIR)/yarl-wasi.tar.gz
WASI_SDK_VERSION := 20.15ge8bb8fade354
WASI_SDK_RELEASE := shared-library-alpha-1
HOST_PLATFORM := $(shell uname -s | sed -e 's/Darwin/macos/' -e 's/Linux/linux/')
PYO3_CROSS_LIB_DIR := $(abspath cpython/builddir/wasi/build/lib.wasi-wasm32-3.11)

.PHONY: all
all: $(OUTPUTS)

$(OUTPUTS): $(WASI_SDK) $(CPYTHON)
	@mkdir -p "$(@D)"
	
	# semi-working:
	(cd aiohttp && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd charset_normalizer && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd frozenlist && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd multidict && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd numpy && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd pandas && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd pydantic-core && PYO3_CROSS_LIB_DIR=$(PYO3_CROSS_LIB_DIR) CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd regex && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd sqlalchemy && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd tiktoken && PYO3_CROSS_LIB_DIR=$(PYO3_CROSS_LIB_DIR) CROSS_PREFIX=$(CPYTHON) SYSCONFIG=$(SYSCONFIG) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd wrapt && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd yaml && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	(cd yarl && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	
	# island of misfit toys:
	#(cd greenlet && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	
	cp -a aiohttp/src/build/*/aiohttp "$(@D)"
	cp -a charset_normalizer/src/build/lib.*/charset_normalizer "$(@D)"
	cp -a frozenlist/src/build/*/frozenlist "$(@D)"
	cp -a multidict/src/build/lib.*/multidict "$(@D)"
	cp -a numpy/numpy/build/lib.*/numpy "$(@D)"
	cp -a pandas/src/build/lib.*/pandas "$(@D)"
	cp -a pydantic-core/src/build/*/pydantic_core "$(@D)"
	cp -a regex/src/build/lib.*/regex "$(@D)"
	cp -a sqlalchemy/src/build/lib.*/sqlalchemy "$(@D)"
	cp -a tiktoken/src/build/lib.*/tiktoken "$(@D)"
	cp -a tiktoken/src/build/lib.*/tiktoken_ext "$(@D)"
	cp -a wrapt/src/build/lib.*/wrapt "$(@D)"
	cp -a yaml/src/build/lib.*/yaml "$(@D)"
	cp -a yaml/src/build/lib.*/_yaml "$(@D)"
	cp -a yarl/src/build/*/yarl "$(@D)"
	
	(cd "$(@D)" && tar czf aiohttp-wasi.tar.gz aiohttp)
	(cd "$(@D)" && tar czf charset_normalizer-wasi.tar.gz charset_normalizer)
	(cd "$(@D)" && tar czf frozenlist-wasi.tar.gz frozenlist)
	(cd "$(@D)" && tar czf multidict-wasi.tar.gz multidict)
	(cd "$(@D)" && tar czf numpy-wasi.tar.gz numpy)
	(cd "$(@D)" && tar czf pandas-wasi.tar.gz pandas)
	(cd "$(@D)" && tar czf pydantic_core-wasi.tar.gz pydantic_core)
	(cd "$(@D)" && tar czf regex-wasi.tar.gz regex)
	(cd "$(@D)" && tar czf sqlalchemy-wasi.tar.gz sqlalchemy)
	(cd "$(@D)" && tar czf tiktoken-wasi.tar.gz tiktoken)
	(cd "$(@D)" && tar czf tiktoken_ext-wasi.tar.gz tiktoken_ext)
	(cd "$(@D)" && tar czf wrapt-wasi.tar.gz wrapt)
	(cd "$(@D)" && tar czf yaml-wasi.tar.gz yaml)
	(cd "$(@D)" && tar czf _yaml-wasi.tar.gz _yaml)
	(cd "$(@D)" && tar czf yarl-wasi.tar.gz yarl)

$(WASI_SDK):
	@mkdir -p "$(@D)"
	(cd "$(@D)" && \
		curl -LO "https://github.com/dicej/wasi-sdk/releases/download/$(WASI_SDK_RELEASE)/wasi-sdk-$(WASI_SDK_VERSION)-$(HOST_PLATFORM).tar.gz" && \
		tar xf "wasi-sdk-$(WASI_SDK_VERSION)-$(HOST_PLATFORM).tar.gz" && \
		mv "wasi-sdk-$(WASI_SDK_VERSION)" wasi-sdk && \
		rm "wasi-sdk-$(WASI_SDK_VERSION)-$(HOST_PLATFORM).tar.gz")

$(CPYTHON): $(WASI_SDK)
	@mkdir -p "$(@D)"
	@mkdir -p "$(@D)"/../build
	@echo "$(@D)"
	(cd "$(@D)"/../build && ../../configure --prefix=$$(pwd)/install && make)
	(cd "$(@D)" && \
		WASI_SDK_PATH=$(WASI_SDK) \
		CONFIG_SITE=../../Tools/wasm/config.site-wasm32-wasi \
		CFLAGS=-fPIC \
		../../Tools/wasm/wasi-env \
		../../configure \
		-C \
		--host=wasm32-unknown-wasi \
		--build=$$(../../config.guess) \
		--with-build-python=$$(if [ -e $$(pwd)/../build/python.exe ]; \
			then echo $$(pwd)/../build/python.exe; \
			else echo $$(pwd)/../build/python; \
			fi) \
		--prefix=$$(pwd)/install \
		--enable-wasm-dynamic-linking \
		--disable-test-modules && \
		make install)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) cpython/builddir numpy/numpy/build
	find . -name 'venv' -depth 2 | xargs -I {} rm -rf {}
	find . -name 'build' -depth 3 | xargs -I {} rm -rf {}
