#!/usr/bin/env bash
set -euo pipefail

: "${GOML_BIN_DIR:?Set GOML_BIN_DIR to the bin directory of an installed GoML toolchain}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
goml_bin="$(cd "$GOML_BIN_DIR" && pwd -P)"
for executable in goml gomlc gomlfmt; do
    test -x "$goml_bin/$executable"
done
output_root="$repository_root/_artifact/example-tests"
tool_prefix="$output_root/tools"
export PATH="$goml_bin:$PATH"
export GOMLC="$goml_bin/gomlc"
bash "$repository_root/build.sh" "$tool_prefix"
cp "$goml_bin/gomlfmt" "$tool_prefix/bin/gomlfmt"
test "$("$tool_prefix/bin/goml-c-bind" --runtime-dir)" = "$tool_prefix/lib/cabi"

(
    cd "$repository_root/examples/bind-c"
    export CGO_ENABLED=1
    "$tool_prefix/bin/goml-c-bind" bindings.json
    "$tool_prefix/bin/goml-c-bind" bindings.json --check
    "$goml_bin/goml" fmt --check
    "$goml_bin/goml" check --target-dir "$output_root/bind-c"
    "$goml_bin/goml" test --target-dir "$output_root/bind-c"
    "$goml_bin/goml" run --target-dir "$output_root/bind-c" > "$output_root/bind-c.out"
    printf '42\nGoML calls C\n255\n' | diff - "$output_root/bind-c.out"
)

(
    cd "$repository_root/examples/go-interop"
    "$goml_bin/goml" fmt --check
    "$goml_bin/goml" check --target-dir "$output_root/go-interop"
    "$goml_bin/goml" test --target-dir "$output_root/go-interop"
    "$goml_bin/goml" run --target-dir "$output_root/go-interop" > "$output_root/go-interop.out"
    printf '3\n42\ntrue\n' | diff - "$output_root/go-interop.out"
)
