#!/usr/bin/env bash
set -euo pipefail

test "$#" = 1 || test "$#" = 3
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
runtime_source="$(cd "$repository_root/lib/cabi" && pwd -P)"
mkdir -p "$1"
output_prefix="$(cd "$1" && pwd -P)"
runtime_destination="$(realpath -m "$output_prefix/lib/cabi")"
if [[ "$runtime_destination" == "$runtime_source" || "$runtime_destination" == "$runtime_source/"* || "$runtime_source" == "$runtime_destination/"* ]]; then
    printf '%s\n' "cannot install C ABI runtime over its source directory" >&2
    exit 1
fi
if [[ -L "$output_prefix/lib/cabi" ]]; then
    printf '%s\n' "C ABI runtime destination must not be a symbolic link" >&2
    exit 1
fi
mkdir -p "$output_prefix/bin" "$output_prefix/lib"
target_goos="${2:-$(go env GOHOSTOS)}"
target_goarch="${3:-$(go env GOHOSTARCH)}"
(
    cd "$repository_root"
    GOWORK=off GO111MODULE=on GOFLAGS= CGO_ENABLED=0 GOOS="$target_goos" GOARCH="$target_goarch" go build -mod=readonly -trimpath -o "$output_prefix/bin/goml-go-meta" .
    GOWORK=off GO111MODULE=on GOFLAGS= CGO_ENABLED=0 GOOS="$target_goos" GOARCH="$target_goarch" go build -mod=readonly -trimpath -o "$output_prefix/bin/goml-c-bind" ./cmd/goml-c-bind
)
rm -rf "$output_prefix/lib/cabi"
cp -R "$runtime_source" "$output_prefix/lib/cabi"
