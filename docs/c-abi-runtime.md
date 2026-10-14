# C ABI runtime

`lib/cabi` is this repository's separate Go and assembly module for the dynamic C binding backend. `build.sh` installs its sources alongside the executables. It has no third-party dependencies and no `import "C"`. Consumers explicitly configure its `github.com/gomlang/goml-go-meta/lib/cabi` requirement and replacement in their Go module; the GoML driver does not inject it. See the [manual tool setup](../README.md#c-bindings-and-runtime). The package is an implementation boundary, not a public GoML raw-pointer API.

## Supported execution environment

The first implementation targets Linux amd64 executables using glibc 2.34 or newer, Go 1.26.x and `CGO_ENABLED=0`. The generator checks the Go version, host target, fixed calling convention and scalar layout. Runtime source constraints reject other Go minor versions and cgo builds. The dynamic imports of pthread creation and library loading require the glibc 2.34 symbol versions. Go minor-version expansion requires reviewing runtime contracts and running the tests against that version first.

The implementation uses Go linker dynamic-import directives to obtain libc entry points and Go runtime linknames for native-call transitions and startup hooks. These directives contain `cgo` in their names, but do not invoke `cmd/cgo`, compile C wrappers, import `runtime/cgo`, or require a C compiler. A finished program still depends on the system ELF loader, glibc and its chosen shared libraries.

## Calling convention

Clang supplies each function's physical signature. During generation, integer and pointer arguments are assigned to RDI, RSI, RDX, RCX, R8 and R9, and floating arguments to XMM0 through XMM7. Overflow arguments are placed in source order into eight-byte stack slots. The generator supports at most 128 scalar parameters, including fixed output pointers. Arguments and results are encoded in a frame whose layout is checked by runtime tests.

The assembly entry preserves its host callee-saved state and maintains 16-byte call-site stack alignment. It copies stack arguments, loads the argument registers, calls the function address, and captures RAX and XMM0. The generated typed wrapper decodes the appropriate result. There is no runtime signature reflection, aggregate classification or variadic promotion. Unsupported signatures are rejected before publishing bindings.

## Threads, stacks and garbage collection

The runtime installs its own initial-stack and thread-start hooks before Go starts. Initial stack bounds come from pthread attributes. New Go runtime threads are created with detached pthreads so glibc TLS, errno and native allocations work on every calling thread. The thread entry installs Go's TLS state using the setter supplied by the Go runtime and enters Go's thread-start function. Signal masks are blocked while creating a thread and restored afterwards. Native thread startup failure is fatal, as it is for Go runtime thread creation.

Native calls use Go's `runtime.cgocall` transition. This releases the scheduler's processor during a blocking C call, switches to the system stack, updates foreign-call accounting, and restores Go execution on return. This is a dependency on Go runtime internals, isolated to the runtime module. Replacing the cgo toolchain does not remove the need for that runtime coordination. See [Go's native-call implementation](https://go.dev/src/runtime/cgocall.go).

The runtime also installs environment-update hooks so Go's environment changes reach libc. The runtime's foreign-callback setup and notification slots have minimal outbound-only implementations; no callback addresses are exposed. Arbitrary foreign threads cannot enter Go through this implementation. C-created threads used internally by a library may operate normally without entering Go.

Generated adapters allocate strings, buffers and out parameters with libc malloc, copy results before freeing temporary storage, and keep the Go call frame live across the transition. These generated data adapters pass only native data pointers to C; the startup and environment hooks follow Go's runtime contract. Opaque pointers remain explicitly managed resources with the same lifetime limitations as the cgo backend. The loader pins the calling OS thread around `dlopen`/`dlsym` and `dlerror` so thread-local error text is copied on the correct thread. Successfully opened libraries are never unloaded.

## Validation

Run `CGO_ENABLED=0 go test -gcflags=all=-d=checkptr=2 ./...` in `lib/cabi`. The tests compile a small shared C fixture, then exercise the first-party runtime: register and stack arguments, mixed float32/float64 arguments, native stack growth, pthread TLS and errno, thread exit, allocations during GC, loader failures, CPU profiling, runtime tracing and a blocking C read while Go has one processor. C fixture compilation is test setup, not part of compiling the runtime or a generated application.

The [C binding fixture](../examples/bind-c/README.md) can be exercised manually with the standalone generator. Run the generator tests from this repository's root with `GOWORK=off go test ./...`; the runtime tests above run separately because `lib/cabi` is its own Go module.
