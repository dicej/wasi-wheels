#!/bin/bash

set -eou pipefail

if [ ! -e venv ]; then
  python3.12 -m venv venv
fi

. venv/bin/activate
pip install -r src/requirements/lint.in -c src/requirements/lint.txt
pip install build wheel setuptools

pushd src
make .install-cython
popd

ARCH_TRIPLET=_wasi_wasm32-wasi

export CC="${WASI_SDK_PATH}/bin/clang"
export CXX="${WASI_SDK_PATH}/bin/clang++"

export PYTHONPATH=$CROSS_PREFIX/lib/python3.12

export CFLAGS="-I${CROSS_PREFIX}/include/python3.12 -D__EMSCRIPTEN__=1"
export CXXFLAGS="-I${CROSS_PREFIX}/include/python3.12"
export LDSHARED=${CC}
export AR="${WASI_SDK_PATH}/bin/ar"
export RANLIB=true
export LDFLAGS="-shared"
export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_${ARCH_TRIPLET}

for i in src/vendor/llhttp/src/native/api.c src/vendor/llhttp/src/native/api.h; do
  if [ $(uname) == 'Darwin' ]; then
    sed -i '' -e 's/__wasm__/__quack__/g' $i
  else
    sed -i -e 's/__wasm__/__quack__/g' $i
  fi
done

cd src

pushd vendor/llhttp/
npm install
make
popd
make cythonize

python3 -m build -n -w
wheel unpack --dest build dist/*.whl

cd vendor/llhttp
git checkout .
