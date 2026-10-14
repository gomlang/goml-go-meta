# Independent Go metadata protocol v1

This is the protocol of the independently built `goml-go-meta` executable. The official compiler, driver and language server do not consume it or invoke the tool. See [manual installation and invocation](../README.md).

Transport is one JSON request on stdin and one JSON response on stdout. stderr is reserved for operational diagnostics. [The protocol package](../internal/protocol/protocol.go) defines the current wire schema. See the [language guide](https://github.com/gomlang/goml/blob/main/docs/goml.md#go-ffi) for source-level bindings and [Go interoperability](https://github.com/gomlang/goml/blob/main/docs/ffi/bind-go.md) for the compiler's trusted declaration model.

Every request contains `protocol_version: 1`, `build_context`, `caller_context`, and `bindings`. Unknown fields, unknown type tags, duplicate or empty binding IDs, malformed/trailing JSON, and invalid contexts are recoverable `ffi-protocol` errors.

`build_context` explicitly carries `go_executable`, `toolchain`, `module_dir`, `goos`, `goarch`, `cgo_enabled`, `goflags`, `build_tags`, `go111module`, `gowork`, `dependencies`, and `network`. v1 uses `gowork: "off"`, `dependencies: "readonly"`, and `network: "off"`. Module mode is `on` or `off`; cgo is `0` or `1`. The client supplies these fields for the Go world it wants to inspect. The host helper itself must be built for the host. Paths are JSON strings, preserved without shell interpretation.

`caller_context` carries `load_mode`, `import_path`, `directory`, and `package` of the actual generated caller. Import legality must be checked in that context, including internal-package restrictions and import cycles. `load_mode` is `package` for a directory package or `files` for an explicit Go file list. File mode requires the import identity `command-line-arguments` and loads only the overlay witness files, excluding stale generated output and unrelated files in that directory. A new library target requires its own validation context.

In file mode, function and type witnesses are combined into one virtual Go source file with normalized import aliases. Loading one file avoids argument-list partitioning that can otherwise discard witnesses when caller paths are long or many bindings are checked. Declaration source mappings preserve per-binding and per-query diagnostics and method selection metadata. The combined file is never written to the caller directory; an existing file at its reserved path is rejected rather than overwritten. Package mode retains separate witnesses and includes the caller package normally.

A binding has `binding_id`, `import_path`, `symbol`, `bridge_parameter_types`, `bridge_result_types`, and `call_mode`. The existing `ordinary` mode uses a nonempty `import_path` and a package-level function symbol. The additive `method` mode requires an empty `import_path` and at least one parameter; parameter zero is the receiver, and `symbol` is its method name. The receiver type supplies any package identity. IDs identify declarations independently of Go symbol spelling. Multiple different IDs may request the same Go symbol. Parameter/result arrays describe the actual Go wrapper operation, not GoML surface types. No results means unit; multiple results mean a flat tuple.

Bridge types use these structured nodes:

| Tag | Additional fields |
| --- | --- |
| `bool`, `int`, `int8`, `int16`, `int32`, `int64`, `uint`, `uint8`, `uint16`, `uint32`, `uint64`, `float32`, `float64`, `string`, `any` | None |
| `pointer` | `element` |
| `array` | `element`, nonnegative `length` |
| `slice` | `element` |
| `map` | `key`, `element` (the value type); Go validates key comparability |
| `channel` | `element`, `direction` (`both`, `send`, `receive`) |
| `function` | `signature` with required `parameters` and `results` arrays |
| `named` | `import_path`, `name`, optional recursive `type_arguments`; builtin `error` uses an empty import path |

GoML isize/usize map to int/uint; char maps to int32 and byte to uint8. Slice and MutSlice share the same Go bridge shape. Direct empty marker data maps to any; any is forbidden inside containers and multiple results. This protocol does not infer Unicode validity, readonly guarantees, or thread safety.

The response envelope contains `protocol_version`, `go_world_identity`, `referenced_types`, `bindings`, and request-level `diagnostics`. A binding result contains `binding_id`, `status`, display-only `actual_signature`, and `diagnostics`. Diagnostic fields are `code`, `message`, and optional `direction` and zero-based `index`. A client may map binding IDs back to its own source spans. Statuses are `verified` and `failed`. `signature_type` references the actual signature node in `referenced_types`; display signatures never serve as type identity. The graph encodes basic, pointer, array, slice, channel, map, alias, named, struct, interface, signature, tuple, type-parameter and union nodes. Nodes use response-local IDs; fields, methods, parameters, results, type arguments, underlying types and constraints refer to those IDs. A visited table preserves cycles. Package path and object name identify named objects within the loaded Go world.

The current codec limits each message to 8 MiB, requests/responses to 4096 bindings, request bridge types to 65536 nodes and 64 nesting levels, and response referenced types to 65536 nodes. Oversized responses are rejected before writing output. The executable defaults to a two-minute timeout (`--timeout`, at most ten minutes). It closes blocked stdin when canceled, passes cancellation to the official package loader, and exits unsuccessfully for failed bindings or request errors. Active package-load cancellation and deadlines have regression tests on the Linux host.

No persistent Verified cache is part of v1. A successful check applies only to the current Go world and caller, and does not authorize comptime or derive execution.

The executable selects the request's Go executable through an isolated temporary `go` symlink on its own PATH, without shell interpolation. It verifies the actual `GOVERSION` against `toolchain`, disables implicit toolchain downloads and workspace mode, requests readonly modules, and disables package-network lookup. The helper is a single-request host process. Its overlay adds witness functions using the requested caller loading mode; caller-directory/import-path disagreement is rejected in module mode. Existing conflicting witness files are rejected, not overwritten. The client is responsible for providing the intended caller package.

Witness function parameters have bridge types. Results are assigned into variables with bridge result types, then returned. A unit declaration emits a call statement, preserving the existing wrapper's ability to discard Go results. Generic inference and fixed variadic argument passing use the same ordinary Go call syntax. For ordinary calls, the checker additionally rejects symbols that are not exported package-level functions. Method witnesses emit `(ReceiverType).Method(receiver, args...)` and use Go type-checker selections to record the actual method signature. This checks the real value/pointer method set, including interfaces, aliases, promoted methods and instantiated named receivers, without implicitly taking the address of a copied receiver. Methods must be exported. A nil pointer is passed unchanged; the witness does not allocate or replace it. The helper reports the selected method signature to its caller.

Clients should reject duplicate, missing or unknown binding results, unknown statuses, inconsistent verified results, non-signature references, unknown referenced-type tags, duplicate type IDs, protocol-version mismatches and oversized or excessively nested JSON. A nonzero helper exit is a failed request.

`caller_context.generated_source` optionally overlays candidate `goml_generated.go` source in package mode. Existing handwritten package files participate in loading; the client owns staging, publication and any subsequent build.

## Type queries

The optional `type_queries` request array and `type_results` response array extend v1 without changing requests that omit them or their responses. Each query has a unique nonempty `type_id`, `import_path`, `name` and optional `type_arguments` and `query_mode`. IDs are unique within the type-query namespace. The combined binding/query count is limited to 4096; arguments share the existing bridge-type depth/node budget. Type arguments use the bridge nodes above. Named nodes also work in helper function witnesses, preserving Go nominal types.

`query_mode` is `instance` by default. Explicit `declaration` mode accepts no type arguments and returns declaration metadata, including generic parameters and constraints, without treating an uninstantiated generic declaration as a value type. It uses a blank-import witness and validates the requested object separately.

The helper creates a type-alias AST witness for each requested concrete type and loads it alongside function witnesses in the same packages.Load world. Type-only requests also load and validate packages. Instantiation and constraint checking use Go's type checker. Missing/private/non-type objects and invalid arguments fail with per-query diagnostics. A query-local type error does not fail an unrelated valid type query or function binding; shared package/load failures affect all dependent results.

Explicit `function` mode queries one exported package-level function named by `import_path` and `name`. Its `type_arguments` enumerate a finite concrete Go instantiation; the official checker rejects missing arguments for generic functions and constraint violations. The helper builds a Go AST variable witness referencing the function (with type arguments when supplied), loads it with the existing read-only build context, and does not execute the function or package initializers. Function variables, types, missing symbols and private functions are rejected.

A type result contains `type_id`, `status`, `diagnostics`, and, when available, `declaration_kind` (`alias`, `defined`, or `function`), `declared_type` and `type`. Both type fields reference nodes in `referenced_types`. `declared_type` describes the original declaration, including its generic parameters. `type` describes the requested concrete type after alias normalization and is absent for declaration queries. For function queries, `declared_type` describes the original function signature and `type` the concrete instantiated signature, including parameter/result lists and the variadic flag. A named interface is distinguishable through its structured underlying interface node. Method sets and instantiated arguments remain in the graph. These session-local node IDs are references, not portable nominal identities.

The helper exits unsuccessfully if any type result fails. These results are inspection data for independent clients; they are not consumed by GoML external-type checking or saved in compiler artifacts.

Builtin Go error uses the named identity with empty import_path, name="error", and no type arguments. The helper emits the Go universe identifier error without an import. Other empty-path named identities and generic error applications are rejected. This is a real interface value, distinct from the legacy any marker; it can occur in tuple results and nested bridge shapes.

Function witnesses use the signature contract for [raw Go function values](https://github.com/gomlang/goml/blob/main/docs/goml.md#raw-go-function-values). Empty parameter/result arrays represent `func()`. Children count toward the same depth and node limits; legacy marker payloads and variadic signatures are rejected.

`source_overlay` is an optional request object with `path` and `source`. It supplies one in-memory Go file under the build module, including a file in an imported package. Paths must be clean, absolute module-contained `.go` paths and cannot use reserved witness filenames. Source is nonempty and bounded by the existing message limit. The helper applies it to the same official Go package load, hashes overlay contents for the Go-world identity, and never writes it to disk. It cannot overlap `caller_context.generated_source`. A client may use a package-only placeholder to omit a previously generated output during discovery, then check a complete candidate source. Existing requests without this optional field retain their behavior.

A client may supply a `-modfile` flag in `goflags`. The helper parses Go-style quoted flags and supplies them as package build flags, keeping them out of the toolchain-version probe that disables module mode. Read-only dependency policy and the original flags in the Go-world identity remain unchanged.

The referenced-type graph can describe Go fields, aliases, interfaces and constraints for independent inspection. It does not make those details available to GoML code. GoML external types remain opaque, and native correctness is checked when generated Go is compiled.
