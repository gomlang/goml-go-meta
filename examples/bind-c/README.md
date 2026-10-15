# Calling C from GoML

This example exercises typed C handles, checked scalar and buffer arguments, copied strings, output parameters, explicit release, and compile-time constants. `sample.h` is a self-contained C library.

Follow the [installation instructions](../../README.md#build-and-install), including the adjacent formatter, and put the installed tool's `bin` directory on `PATH`. Also install the GoML toolchain and make `goml` available on `PATH`. With Go 1.26, Clang and a C compiler available, run from this directory:

```sh
CGO_ENABLED=1 goml-c-bind bindings.json
CGO_ENABLED=1 goml test
CGO_ENABLED=1 goml run
```

Output is `42`, `GoML calls C`, and `255`. `bindings/generated.goml`, `native/generated.go` and `bindings.json.goml-c-bind.json` are generated together. Run `CGO_ENABLED=1 goml-c-bind bindings.json --check` explicitly to verify output against C inputs.

The checked-in configuration uses cgo. See the [C binding guide](../../docs/bind-c.md) for the supported mappings, lifetime rules and dynamic backend. Dynamic consumers also need an explicit runtime dependency as described in [runtime setup](../../README.md#c-bindings-and-runtime).

The repository's [example test script](../../test-examples.sh) builds a fresh generator installation, copies the formatter from the selected GoML installation, runs these commands and checks the exact program output.
