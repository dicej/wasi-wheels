#!/bin/bash

set -eou pipefail

ARCH_TRIPLET=_wasi_wasm32-wasi

export CC="${WASI_SDK_PATH}/bin/clang"
export CXX="${WASI_SDK_PATH}/bin/clang++"

export PYTHONPATH=$CROSS_PREFIX/lib/python3.11

export CFLAGS="-I${CROSS_PREFIX}/include/python3.11 -D__EMSCRIPTEN__=1 -DNPY_NO_SIGNAL"
export CXXFLAGS="-I${CROSS_PREFIX}/include/python3.11"
export LDSHARED=${CC}
export AR="${WASI_SDK_PATH}/bin/ar"
export RANLIB=true
export LDFLAGS="-shared"
export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_${ARCH_TRIPLET}
export NPY_DISABLE_SVML=1
export NPY_BLAS_ORDER=
export NPY_LAPACK_ORDER=

pip3 install cython
(cd src && python3 setup.py build --disable-optimization -j 4)

#cp -a numpy/build/lib.*/numpy build/
