#!/bin/bash

set -eou pipefail

if [ ! -e venv ]; then
  python3 -m venv venv
fi

. venv/bin/activate
pip install expandvars wheel
pip install -r src/requirements/ci.txt

ARCH_TRIPLET=_wasi_wasm32-wasi

export CC="${WASI_SDK_PATH}/bin/clang"
export CXX="${WASI_SDK_PATH}/bin/clang++"

export PYTHONPATH=$CROSS_PREFIX/lib/python3.11

export CFLAGS="-I${CROSS_PREFIX}/include/python3.11 -D__EMSCRIPTEN__=1"
export CXXFLAGS="-I${CROSS_PREFIX}/include/python3.11"
export LDSHARED=${CC}
export AR="${WASI_SDK_PATH}/bin/ar"
export RANLIB=true
export LDFLAGS="-shared"
export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_${ARCH_TRIPLET}

(cd src && python3 -m build -n -w)
