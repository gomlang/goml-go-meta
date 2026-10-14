# Explicit Go wrappers

This example contains checked-in GoML declarations and Go forwarding functions for `strings.Count` and `strconv.Atoi`. Text conversion and error handling remain explicit in `main.goml`.

Install the [GoML toolchain](https://github.com/gomlang/goml/blob/main/docs/releasing.md#installation) separately and make `goml` available on `PATH`. With Go 1.26 or newer, run from this directory:

```sh
goml check
goml run
```

The output is:

```text
3
42
true
```

`bindings/generated.goml` and `native/generated.go` are ordinary source inputs. The historical JSON configuration and ownership manifest record how they were generated; the tools in this repository do not regenerate Go bindings. The final Go build validates calls through the explicit declarations. See [Go interoperability](https://github.com/gomlang/goml/blob/main/docs/ffi/bind-go.md) for the declaration model.
