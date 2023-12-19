#!/bin/bash

set -eou pipefail

if [ ! -e venv ]; then
  echo 'creating venv'
  python3 -m venv venv
fi

. venv/bin/activate
pip install typing-extensions wheel

ARCH_TRIPLET=_wasi_wasm32-wasi

export CC="${WASI_SDK_PATH}/bin/clang"
export CXX="${WASI_SDK_PATH}/bin/clang++"

export PYTHONPATH=$CROSS_PREFIX/lib/python3.11
export RUSTFLAGS="-C link-args=-L${WASI_SDK_PATH}/build/install/opt/wasi-sdk/share/wasi-sysroot/lib/wasm32-wasi -C linker=${WASI_SDK_PATH}/bin/wasm-ld"
export CFLAGS="-I${CROSS_PREFIX}/include/python3.11 -D__EMSCRIPTEN__=1"
export CXXFLAGS="-I${CROSS_PREFIX}/include/python3.11"
export LDSHARED=${CC}
export AR="${WASI_SDK_PATH}/bin/ar"
export RANLIB=true
export LDFLAGS="-shared"
export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_${ARCH_TRIPLET}
export CARGO_BUILD_TARGET=wasm32-wasi
cd src
rm -rf build
mkdir build
maturin build --release --target wasm32-wasi --out dist -i python3.11
wheel unpack --dest build dist/*.whl 
