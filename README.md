# goml-go-meta

Standalone Go metadata inspection and C binding tools for [GoML](https://github.com/gomlang/goml).

- `goml-go-meta` reads a JSON request and reports Go signatures, types, aliases, fields, interfaces and constraints using Go's package loader and type checker.
- `goml-c-bind` generates GoML declarations and Go bridges from an explicit C allowlist. It supports cgo and a dynamic backend using this repository's C ABI runtime.

These tools run explicitly. GoML compilation uses the foreign signatures declared in GoML and leaves native checks to the final Go build; metadata inspection does not change that compiler behavior. This repository does not provide a Go binding generator.

## Build and install

From the repository root, with Go 1.26 or newer:

```sh
bash build.sh _artifact/install
```

The script builds `_artifact/install/bin/goml-go-meta` and `_artifact/install/bin/goml-c-bind`, then installs the runtime source under `_artifact/install/lib/cabi`. An optional second and third argument select the target OS and architecture. Invoke the binaries by their paths or add the installation's `bin` directory to `PATH`.

C binding generation also requires Clang 15 or newer and an adjacent GoML formatter. Copy `gomlfmt` from a separately installed GoML toolchain:

```sh
cp /path/to/goml/bin/gomlfmt _artifact/install/bin/gomlfmt
```

The cgo backend requires a C compiler and `CGO_ENABLED=1`. The dynamic backend requires Linux amd64, glibc 2.34+, Go 1.26.x and `CGO_ENABLED=0`.

## Go metadata inspection

Supply one JSON request on standard input; the response is written to standard output:

```sh
_artifact/install/bin/goml-go-meta < request.json > response.json
```

The [protocol reference](docs/protocol-v1.md) describes build and caller contexts, binding checks, type queries, diagnostics and limits. The helper checks declarations without executing Go package initializers.

## C bindings and runtime

Generate or verify bindings explicitly:

```sh
_artifact/install/bin/goml-c-bind path/to/bindings.json
_artifact/install/bin/goml-c-bind path/to/bindings.json --check
_artifact/install/bin/goml-c-bind --runtime-dir
```

The last command prints the installed runtime directory. The tool resolves symlinks to its executable and finds `../lib/cabi`; keep `bin` and `lib` together when relocating the installation.

The root Go module is `github.com/gomlang/goml-go-meta`. The runtime is a separate module, `github.com/gomlang/goml-go-meta/lib/cabi`. A dynamic binding consumer must explicitly provide the runtime in its Go module. For a local installation, run these commands in the consuming module with the actual absolute runtime path:

```sh
go mod edit -require=github.com/gomlang/goml-go-meta/lib/cabi@v0.0.0
go mod edit -replace=github.com/gomlang/goml-go-meta/lib/cabi=/absolute/path/to/install/lib/cabi
```

The generator uses its installed runtime to check candidate output but does not add that dependency to the consuming module. GoML project commands compile generated files as ordinary sources; run generation and verification yourself when inputs change.

See the [C binding guide](docs/bind-c.md), [runtime design](docs/c-abi-runtime.md), [C example](examples/bind-c/README.md) and [explicit Go wrapper example](examples/go-interop/README.md).

## Tests

Run the Go tool tests from the repository root:

```sh
GOWORK=off go test ./...
```

C generator tests require Clang and a C compiler. The runtime has its own nested module and tests; on its supported host, run:

```sh
cd lib/cabi
GOWORK=off CGO_ENABLED=0 go test -gcflags=all=-d=checkptr=2 ./...
```

The runtime tests compile a C fixture, so their setup also requires a C compiler. The GoML examples require a separately installed `goml`, `gomlc` and their toolchain resources; their READMEs contain the test and run commands.

To check both examples against an installed GoML 0.1.60 or newer toolchain:

```sh
GOML_BIN_DIR=/absolute/path/to/goml/bin bash test-examples.sh
```

This builds a fresh standalone tool installation, copies the selected toolchain's formatter, regenerates and verifies the C bindings, and checks, tests and runs both examples with exact output assertions. All build outputs go under `_artifact/example-tests`. CI uses the checksum-pinned GoML 0.1.60 release; the same script accepts a local compiler build while retaining its adjacent library resources.
