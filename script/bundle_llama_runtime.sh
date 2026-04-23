#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/TextKit.app" >&2
  exit 2
fi

APP_BUNDLE="$1"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"
RUNTIME_ROOT="$APP_RESOURCES/Runtime"
RUNTIME_BIN="$RUNTIME_ROOT/bin"
RUNTIME_LIB="$RUNTIME_ROOT/lib"
RUNTIME_BACKENDS="$RUNTIME_ROOT/backends"

realpath_py() {
  /usr/bin/python3 - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

require_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "Required runtime artifact missing: $path" >&2
    exit 1
  fi
}

maybe_change_install_name() {
  local target="$1"
  local from="$2"
  local to="$3"

  if otool -L "$target" | grep -Fq "$from"; then
    install_name_tool -change "$from" "$to" "$target"
  fi
}

copy_as() {
  local source="$1"
  local destination="$2"

  require_file "$source"
  cp -f "$source" "$destination"
  chmod u+w "$destination"
}

mkdir -p "$RUNTIME_BIN" "$RUNTIME_LIB" "$RUNTIME_BACKENDS"

LLAMA_COMPLETION_SOURCE="$(realpath_py /opt/homebrew/bin/llama-completion)"
LLAMA_CLI_SOURCE="$(realpath_py /opt/homebrew/bin/llama-cli)"
LLAMA_SERVER_SOURCE="$(realpath_py /opt/homebrew/bin/llama-server)"

LIB_LLAMA_COMMON_SOURCE="$(realpath_py /opt/homebrew/opt/llama.cpp/lib/libllama-common.0.dylib)"
LIB_LLAMA_SOURCE="$(realpath_py /opt/homebrew/opt/llama.cpp/lib/libllama.0.dylib)"
LIB_MTMD_SOURCE="$(realpath_py /opt/homebrew/opt/llama.cpp/lib/libmtmd.0.dylib)"

LIB_GGML_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/lib/libggml.0.dylib)"
LIB_GGML_BASE_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/lib/libggml-base.0.dylib)"

LIB_SSL_SOURCE="$(realpath_py /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib)"
LIB_CRYPTO_SOURCE="$(realpath_py /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib)"
LIB_OMP_SOURCE="$(realpath_py /opt/homebrew/opt/libomp/lib/libomp.dylib)"

BACKEND_METAL_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/libexec/libggml-metal.so)"
BACKEND_BLAS_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/libexec/libggml-blas.so)"
BACKEND_CPU_M1_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/libexec/libggml-cpu-apple_m1.so)"
BACKEND_CPU_M2_M3_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/libexec/libggml-cpu-apple_m2_m3.so)"
BACKEND_CPU_M4_SOURCE="$(realpath_py /opt/homebrew/opt/ggml/libexec/libggml-cpu-apple_m4.so)"

copy_as "$LLAMA_COMPLETION_SOURCE" "$RUNTIME_BIN/llama-completion"
copy_as "$LLAMA_CLI_SOURCE" "$RUNTIME_BIN/llama-cli"
copy_as "$LLAMA_SERVER_SOURCE" "$RUNTIME_BIN/llama-server"

copy_as "$LIB_LLAMA_COMMON_SOURCE" "$RUNTIME_LIB/libllama-common.0.dylib"
copy_as "$LIB_LLAMA_SOURCE" "$RUNTIME_LIB/libllama.0.dylib"
copy_as "$LIB_MTMD_SOURCE" "$RUNTIME_LIB/libmtmd.0.dylib"
copy_as "$LIB_GGML_SOURCE" "$RUNTIME_LIB/libggml.0.dylib"
copy_as "$LIB_GGML_BASE_SOURCE" "$RUNTIME_LIB/libggml-base.0.dylib"
copy_as "$LIB_SSL_SOURCE" "$RUNTIME_LIB/libssl.3.dylib"
copy_as "$LIB_CRYPTO_SOURCE" "$RUNTIME_LIB/libcrypto.3.dylib"
copy_as "$LIB_OMP_SOURCE" "$RUNTIME_LIB/libomp.dylib"

copy_as "$BACKEND_METAL_SOURCE" "$RUNTIME_BACKENDS/libggml-metal.so"
copy_as "$BACKEND_BLAS_SOURCE" "$RUNTIME_BACKENDS/libggml-blas.so"
copy_as "$BACKEND_CPU_M1_SOURCE" "$RUNTIME_BACKENDS/libggml-cpu-apple_m1.so"
copy_as "$BACKEND_CPU_M2_M3_SOURCE" "$RUNTIME_BACKENDS/libggml-cpu-apple_m2_m3.so"
copy_as "$BACKEND_CPU_M4_SOURCE" "$RUNTIME_BACKENDS/libggml-cpu-apple_m4.so"

chmod +x "$RUNTIME_BIN/llama-completion" "$RUNTIME_BIN/llama-cli" "$RUNTIME_BIN/llama-server"

install_name_tool -id "@loader_path/libllama-common.0.dylib" "$RUNTIME_LIB/libllama-common.0.dylib"
install_name_tool -id "@loader_path/libllama.0.dylib" "$RUNTIME_LIB/libllama.0.dylib"
install_name_tool -id "@loader_path/libmtmd.0.dylib" "$RUNTIME_LIB/libmtmd.0.dylib"
install_name_tool -id "@loader_path/libggml.0.dylib" "$RUNTIME_LIB/libggml.0.dylib"
install_name_tool -id "@loader_path/libggml-base.0.dylib" "$RUNTIME_LIB/libggml-base.0.dylib"
install_name_tool -id "@loader_path/libssl.3.dylib" "$RUNTIME_LIB/libssl.3.dylib"
install_name_tool -id "@loader_path/libcrypto.3.dylib" "$RUNTIME_LIB/libcrypto.3.dylib"
install_name_tool -id "@loader_path/libomp.dylib" "$RUNTIME_LIB/libomp.dylib"

for binary in "$RUNTIME_BIN/llama-completion" "$RUNTIME_BIN/llama-cli" "$RUNTIME_BIN/llama-server"; do
  maybe_change_install_name "$binary" "@rpath/libllama-common.0.dylib" "@executable_path/../lib/libllama-common.0.dylib"
  maybe_change_install_name "$binary" "@rpath/libllama.0.dylib" "@executable_path/../lib/libllama.0.dylib"
  maybe_change_install_name "$binary" "@rpath/libmtmd.0.dylib" "@executable_path/../lib/libmtmd.0.dylib"
  maybe_change_install_name "$binary" "/opt/homebrew/opt/ggml/lib/libggml.0.dylib" "@executable_path/../lib/libggml.0.dylib"
  maybe_change_install_name "$binary" "/opt/homebrew/opt/ggml/lib/libggml-base.0.dylib" "@executable_path/../lib/libggml-base.0.dylib"
  maybe_change_install_name "$binary" "/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib" "@executable_path/../lib/libssl.3.dylib"
  maybe_change_install_name "$binary" "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib" "@executable_path/../lib/libcrypto.3.dylib"
done

for library in \
  "$RUNTIME_LIB/libllama-common.0.dylib" \
  "$RUNTIME_LIB/libllama.0.dylib" \
  "$RUNTIME_LIB/libmtmd.0.dylib" \
  "$RUNTIME_LIB/libggml.0.dylib" \
  "$RUNTIME_LIB/libggml-base.0.dylib" \
  "$RUNTIME_LIB/libssl.3.dylib"; do
  maybe_change_install_name "$library" "@rpath/libllama.0.dylib" "@loader_path/libllama.0.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/llama.cpp/lib/libllama-common.0.dylib" "@loader_path/libllama-common.0.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/llama.cpp/lib/libllama.0.dylib" "@loader_path/libllama.0.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/llama.cpp/lib/libmtmd.0.dylib" "@loader_path/libmtmd.0.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/ggml/lib/libggml.0.dylib" "@loader_path/libggml.0.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/ggml/lib/libggml-base.0.dylib" "@loader_path/libggml-base.0.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib" "@loader_path/libssl.3.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/Cellar/openssl@3/3.6.2/lib/libcrypto.3.dylib" "@loader_path/libcrypto.3.dylib"
  maybe_change_install_name "$library" "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib" "@loader_path/libcrypto.3.dylib"
done

for backend in \
  "$RUNTIME_BACKENDS/libggml-metal.so" \
  "$RUNTIME_BACKENDS/libggml-blas.so" \
  "$RUNTIME_BACKENDS/libggml-cpu-apple_m1.so" \
  "$RUNTIME_BACKENDS/libggml-cpu-apple_m2_m3.so" \
  "$RUNTIME_BACKENDS/libggml-cpu-apple_m4.so"; do
  maybe_change_install_name "$backend" "@rpath/libggml-base.0.dylib" "@loader_path/../lib/libggml-base.0.dylib"
  maybe_change_install_name "$backend" "/opt/homebrew/opt/libomp/lib/libomp.dylib" "@loader_path/../lib/libomp.dylib"
done

codesign --force --sign - "$RUNTIME_LIB/libllama.0.dylib"
codesign --force --sign - "$RUNTIME_LIB/libllama-common.0.dylib"
codesign --force --sign - "$RUNTIME_LIB/libmtmd.0.dylib"
codesign --force --sign - "$RUNTIME_LIB/libggml.0.dylib"
codesign --force --sign - "$RUNTIME_LIB/libggml-base.0.dylib"
codesign --force --sign - "$RUNTIME_LIB/libssl.3.dylib"
codesign --force --sign - "$RUNTIME_LIB/libcrypto.3.dylib"
codesign --force --sign - "$RUNTIME_LIB/libomp.dylib"

codesign --force --sign - "$RUNTIME_BACKENDS/libggml-metal.so"
codesign --force --sign - "$RUNTIME_BACKENDS/libggml-blas.so"
codesign --force --sign - "$RUNTIME_BACKENDS/libggml-cpu-apple_m1.so"
codesign --force --sign - "$RUNTIME_BACKENDS/libggml-cpu-apple_m2_m3.so"
codesign --force --sign - "$RUNTIME_BACKENDS/libggml-cpu-apple_m4.so"

codesign --force --sign - "$RUNTIME_BIN/llama-completion"
codesign --force --sign - "$RUNTIME_BIN/llama-cli"
codesign --force --sign - "$RUNTIME_BIN/llama-server"
