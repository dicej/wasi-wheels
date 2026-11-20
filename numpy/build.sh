#!/bin/bash

set -eou pipefail

PYTHON_BIN="${BUILD_PYTHON:-python3.15}"

if [ ! -e venv ]; then
  "${PYTHON_BIN}" -m venv venv
fi

. venv/bin/activate

pip install "Cython>=3.1.0" "meson-python>=0.18.0" ninja

WORK_DIR="$(pwd)/build"
mkdir -p "${WORK_DIR}"

python3 - "${CROSS_PREFIX}" "${WORK_DIR}/build-details.json" << 'EOF'
import json, pathlib, sys

cross_prefix = pathlib.Path(sys.argv[1]).resolve()
out_path = pathlib.Path(sys.argv[2])

src_details = cross_prefix / "lib" / "python3.15" / "build-details.json"
data = json.loads(src_details.read_text(encoding="utf-8"))

data["base_prefix"] = str(cross_prefix)
data["platform"] = "wasi-wasm32"
data["abi"]["extension_suffix"] = ".cpython-315-wasm32-wasi.so"
data["abi"]["stable_abi_suffix"] = ".abi3.so"
data["suffixes"]["extensions"] = [".cpython-315-wasm32-wasi.so", ".abi3.so", ".so"]
data["libpython"] = {
    "dynamic": str(cross_prefix / "lib" / "libpython3.15.so"),
    "static": str(cross_prefix / "lib" / "libpython3.15.a"),
    "link_extensions": True,
}
data["c_api"]["headers"] = str(cross_prefix / "include" / "python3.15")
data["c_api"]["pkgconfig_path"] = str(cross_prefix / "lib" / "pkgconfig")

out_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
EOF

SYSROOT="${WASI_SDK_PATH}/share/wasi-sysroot"
COMMON_DEFS="'-D_WASI_EMULATED_SIGNAL', '-D_WASI_EMULATED_PROCESS_CLOCKS', '-D_WASI_EMULATED_MMAN', '-D_WASI_EMULATED_GETPID', '-DNPY_NO_SIGNAL'"
COMMON_LIBS="'-lwasi-emulated-signal', '-lwasi-emulated-process-clocks', '-lwasi-emulated-mman', '-lwasi-emulated-getpid'"

SETUP_FLAG=""
if [ -d "${WORK_DIR}/meson-build" ]; then
  SETUP_FLAG="--reconfigure"
fi

export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="${CROSS_PREFIX}/lib/pkgconfig:${SYSROOT}/lib/pkgconfig:${SYSROOT}/share/pkgconfig"

cat > "${WORK_DIR}/wasm-ld-wrap" << EOF
#!/usr/bin/env python3
import os, sys

out = ["${WASI_SDK_PATH}/bin/wasm-ld"]
if "-lc++" in sys.argv:
    out.append("-L${SYSROOT}/lib/wasm32-wasip2/eh")
it = iter(sys.argv[1:])
for arg in it:
    if arg in ("--start-group", "--end-group", "-Bsymbolic", "-Bsymbolic-functions"):
        continue
    if arg == "-soname":
        next(it, None)
        continue
    if arg.startswith("-soname="):
        continue
    out.append(arg)
if "-lc++" in sys.argv:
    out.extend(["-lc++abi", "-lunwind"])
if "-shared" in sys.argv:
    out.append("${CROSS_PREFIX}/lib/libpython3.15.so")
os.execv(out[0], out)
EOF
chmod +x "${WORK_DIR}/wasm-ld-wrap"

cat > "${WORK_DIR}/wasi-cross.ini" << EOF
[binaries]
c = ['${WASI_SDK_PATH}/bin/clang', '--target=wasm32-wasip2', '--sysroot=${SYSROOT}']
cpp = ['${WASI_SDK_PATH}/bin/clang++', '--target=wasm32-wasip2', '--sysroot=${SYSROOT}']
c_ld = '${WORK_DIR}/wasm-ld-wrap'
cpp_ld = '${WORK_DIR}/wasm-ld-wrap'
ar = '${WASI_SDK_PATH}/bin/llvm-ar'
ranlib = '${WASI_SDK_PATH}/bin/llvm-ranlib'
strip = '${WASI_SDK_PATH}/bin/llvm-strip'
pkg-config = 'pkg-config'

[built-in options]
c_args = ['-fPIC', ${COMMON_DEFS}]
cpp_args = ['-fPIC', '-fwasm-exceptions', '-mllvm', '-wasm-use-legacy-eh=false', ${COMMON_DEFS}]
c_link_args = [${COMMON_LIBS}]
cpp_link_args = ['-fwasm-exceptions', '-L${SYSROOT}/lib/wasm32-wasip2/eh', ${COMMON_LIBS}]

[host_machine]
system = 'wasi'
cpu_family = 'wasm32'
cpu = 'wasm32'
endian = 'little'

[properties]
needs_exe_wrapper = true
longdouble_format = 'IEEE_QUAD_LE'
EOF

(
  cd src
  python3 vendored-meson/meson/meson.py setup ${SETUP_FLAG} "${WORK_DIR}/meson-build" \
    --cross-file="${WORK_DIR}/wasi-cross.ini" \
    -Dbuildtype=release \
    -Dallow-noblas=true \
    -Dblas="" \
    -Dlapack="" \
    -Ddisable-threading=true \
    -Ddisable-optimization=true \
    -Ddisable-svml=true \
    -Ddisable-highway=true \
    -Ddisable-intel-sort=true \
    -Dpython.build_config="${WORK_DIR}/build-details.json"
  python3 vendored-meson/meson/meson.py compile -C "${WORK_DIR}/meson-build"
  rm -rf "${WORK_DIR}/stage"
  python3 vendored-meson/meson/meson.py install -C "${WORK_DIR}/meson-build" \
    --destdir="${WORK_DIR}/stage" \
    --tags=runtime,python-runtime,devel
)

rm -rf "${WORK_DIR}/numpy"
NUMPY_PKG_DIR="$(find "${WORK_DIR}/stage" -type d -name numpy | head -n 1)"
cp -a "${NUMPY_PKG_DIR}" "${WORK_DIR}/numpy"
find "${WORK_DIR}/numpy" -name '__pycache__' -type d -exec rm -rf {} +
