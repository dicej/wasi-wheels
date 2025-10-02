#!/bin/bash

set -eou pipefail

ARCH_TRIPLET=_wasi_wasm32-wasi

if [ ! -e venv ]; then
  python3.14 -m venv venv
fi

. venv/bin/activate

export CC="${WASI_SDK_PATH}/bin/clang"
export CXX="${WASI_SDK_PATH}/bin/clang++"

export PYTHONPATH=$CROSS_PREFIX/lib/python3.14

export CFLAGS="--target=wasm32-wasip2 -I${CROSS_PREFIX}/include/python3.14 -D__EMSCRIPTEN__=1 -DNPY_NO_SIGNAL"
export CXXFLAGS="--target=wasm32-wasip2 -I${CROSS_PREFIX}/include/python3.14"
export LDSHARED=${CC}
export AR="${WASI_SDK_PATH}/bin/ar"
export RANLIB=true
export LDFLAGS="--target=wasm32-wasip2 -shared ${CROSS_PREFIX}/lib/libpython3.14.so"
export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_${ARCH_TRIPLET}
export NPY_DISABLE_SVML=1
export NPY_BLAS_ORDER=
export NPY_LAPACK_ORDER=

pip install cython==3.0.12 setuptools==71.1.0
( cd src && python3 setup.py build --disable-optimization -j 4 )

cp -a src/build/lib.*/numpy build/
