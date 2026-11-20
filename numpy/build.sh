#!/bin/bash

set -x
set -eou pipefail

cat >patch.txt <<EOF
diff --git a/numpy/_core/src/multiarray/temp_elide.c b/numpy/_core/src/multiarray/temp_elide.c
index 6a26ee1f74..dc2bc8e452 100644
--- a/numpy/_core/src/multiarray/temp_elide.c
+++ b/numpy/_core/src/multiarray/temp_elide.c
@@ -59,7 +59,7 @@
  * supported too by using the appropriate Windows APIs.
  */

-#if defined HAVE_BACKTRACE && defined HAVE_DLFCN_H
+#if defined HAVE_BACKTRACE && defined HAVE_DLFCN_H && !(defined __wasi__)

 #include <feature_detection_misc.h>

EOF

(cd src && git apply ../patch.txt || git apply ../patch.txt --reverse --check)

sed "s^WASI_SDK_PATH^${WASI_SDK_PATH}^" >wasm-ld-wrapper.sh <<'EOF'
#!/bin/bash

args=("$@")
for ((i=0; i<"${#args[@]}"; ++i)); do
  case ${args[i]} in
    --start-group)
      unset args[i]
      ;;

    --end-group)
      unset args[i]
      ;;
  esac
done
WASI_SDK_PATH/bin/wasm-ld "${args[@]}"
EOF
chmod +x wasm-ld-wrapper.sh

SYSROOT="${WASI_SDK_PATH}/share/wasi-sysroot"
cat >cross.txt <<EOF
[constants]
numpy = '${NUMPY_PATH}'
wasi_sdk = '${WASI_SDK_PATH}'
cpython = '${CPYTHON_PATH}/builddir/wasip3/install'

[built-in options]
c_args = ['--target=wasm32-wasip3', '-I' + cpython + '/include/python3.15', '-D__EMSCRIPTEN__=1', '-DNPY_NO_SIGNAL', '-fwasm-exceptions', '-mllvm', '-wasm-use-legacy-eh=false']
cpp_args = c_args
c_link_args = ['--target=wasm32-wasip3', '-shared', cpython + '/lib/libpython3.15.so', wasi_sdk + '/share/wasi-sysroot/lib/wasm32-wasip3/eh/libunwind.so', '-fwasm-exceptions', '-mllvm', '-wasm-use-legacy-eh=false']
cpp_link_args = c_link_args

[binaries]
c = wasi_sdk / 'bin/clang'
cpp = wasi_sdk / 'bin/clang++'
ar = wasi_sdk / 'bin/ar'
ld = numpy + '/wasm-ld-wrapper.sh'
c_ld = ld
cpp_ld = ld

[properties]
needs_exe_wrapper = true
longdouble_format = 'IEEE_QUAD_LE'

[host_machine]
system = 'wasip3'
cpu_family = 'wasm32'
cpu = 'wasm'
endian = 'little'
EOF

jq -r '(.abi.extension_suffix |= ".cpython-315-wasm32-wasi.so")
   | (.suffixes.extensions |= [".cpython-315-wasm32-wasi.so", ".abi3.so", ".so"])
   | (.abi.stable_abi_suffix |= ".abi3.so")
   | (.libpython.dynamic |= "'"${CPYTHON_PATH}"'/builddir/wasip3/install/lib/libpython3.15.so")
   | (.libpython.link_extensions |= true)' \
   >build-details.json <${CPYTHON_PATH}/builddir/wasip3/install/lib/python3.15/build-details.json

${CPYTHON_PATH}/builddir/build/install/bin/python3.15 -m venv venv
source venv/bin/activate
pip install meson-python cython ninja
cd src
python vendored-meson/meson/meson.py setup --reconfigure ${NUMPY_PATH}/src ${NUMPY_PATH}/src/wasi-build -Dbuildtype=release -Db_ndebug=if-release -Db_vscrt=md --cross-file=${NUMPY_PATH}/cross.txt -Dpython.build_config=${NUMPY_PATH}/build-details.json
cd wasi-build
python ../vendored-meson/meson/meson.py install --destdir install
deactivate

