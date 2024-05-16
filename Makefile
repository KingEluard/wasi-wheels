BUILD_DIR := $(abspath build)
WASI_SDK := $(BUILD_DIR)/wasi-sdk
CPYTHON := $(abspath cpython/builddir/wasi/install)
OUTPUT := $(BUILD_DIR)/scipy-wasi.tar.gz
WASI_SDK_VERSION := 20.31gfe4d2f01387d
WASI_SDK_RELEASE := shared-library-alpha-3
HOST_PLATFORM := $(shell uname -s | sed -e 's/Darwin/macos/' -e 's/Linux/linux/')
PYO3_CROSS_LIB_DIR := $(abspath cpython/builddir/wasi/build/lib.wasi-wasm32-3.12)

.PHONY: all
all: $(OUTPUT)

$(OUTPUT): $(WASI_SDK) $(CPYTHON)
	@mkdir -p $(@D)
	(cd scipy && CROSS_PREFIX=$(CPYTHON) WASI_SDK_PATH=$(WASI_SDK) bash build.sh)
	cp -a scipy/src/build/lib.*/scipy $(@D)
	(cd $(@D) && tar czf scipy-wasi.tar.gz scipy)

$(WASI_SDK):
	@mkdir -p $(@D)
	(cd $(@D) && \
		curl -LO "https://github.com/dicej/wasi-sdk/releases/download/$(WASI_SDK_RELEASE)/wasi-sdk-$(WASI_SDK_VERSION)-$(HOST_PLATFORM).tar.gz" && \
		tar xf "wasi-sdk-$(WASI_SDK_VERSION)-$(HOST_PLATFORM).tar.gz" && \
		mv "wasi-sdk-$(WASI_SDK_VERSION)" wasi-sdk && \
		rm "wasi-sdk-$(WASI_SDK_VERSION)-$(HOST_PLATFORM).tar.gz")

$(CPYTHON): $(WASI_SDK)
	@mkdir -p $(@D)
	@mkdir -p $(@D)/../build
	@echo $(@D)
	(cd $(@D)/../build && ../../configure --prefix=$$(pwd)/install && make)
	(cd $(@D) && \
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
		--enable-ipv6 \
		--disable-test-modules && \
		make install)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) cpython/builddir numpy/numpy/build
	find . -name 'venv' -maxdepth 2 | xargs -I {} rm -rf {}
	find . -name 'build' -maxdepth 3 | xargs -I {} rm -rf {}
	find . -name 'dist' -maxdepth 3 | xargs -I {} rm -rf {}
