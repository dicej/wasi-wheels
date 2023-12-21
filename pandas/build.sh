#!/bin/bash

set -eou pipefail

if [ ! -e venv ]; then
  python3 -m venv venv
fi

. venv/bin/activate
pip install build wheel meson[ninja]==1.2.1 meson-python==0.13.1 versioneer[toml] 'numpy<2' Cython==3.0.5

# Truly, the "Good Code"
#
# Turn off setjmp instructions because we don't have access to them under WASI.
# Ideally we'd be compiling pandas' copy of numpy against the WASI numpy we've
# already built, but it seems like pandas is set up to compile against a local,
# import-able copy of numpy instead.
cat >venv/lib/python3.11/site-packages/numpy/core/include/numpy/npy_interrupt.h <<'EOF'

#ifndef NUMPY_CORE_INCLUDE_NUMPY_NPY_INTERRUPT_H_
#define NUMPY_CORE_INCLUDE_NUMPY_NPY_INTERRUPT_H_


#define NPY_SIGINT_ON
#define NPY_SIGINT_OFF

#endif  /* NUMPY_CORE_INCLUDE_NUMPY_NPY_INTERRUPT_H_ */
EOF

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
export NPY_DISABLE_SVML=1
export NPY_BLAS_ORDER=
export NPY_LAPACK_ORDER=
export NPY_NO_SIGNAL=1
export MACOSX_DEPLOYMENT_TARGET=3.11

cd src
python3 setup.py build -j 4
# wheel unpack --dest build dist/*.whl 
