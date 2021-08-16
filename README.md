# EXLA precompiled

> **Disclaimer:** this project is an experiment attempting to ease
> local development and speed up getting started with EXLA. It shouldn't
> be considered a production-oriented solution.

Precompiled [EXLA](https://github.com/elixir-nx/nx/tree/main/exla) binaries
for common targets.

## Usage

All you need is adding `exla_precompiled` to your dependencies:

```elixir
def deps do
  [
    {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "nx", override: true},
    {:exla, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "exla"},
    {:exla_precompiled, "~> 0.1.0-dev", github: "jonatanklosko/exla_precompiled"}
  ]
end
```

The package itself doesn't have any dependencies, so make sure to keep
both `nx` and `exla` listed.

## Limitations

Currently the binaries are built only for Linux x86_64 and macOS x86_64,
in both cases targeting the CPU.

## How it works

The binaries are periodically built by CI and published as a GitHub release.
Then, when you install the package locally it will look up a binary for the
specific revision of `exla` that you depend on. If available, the binary is
downloaded and placed in the `exla` priv directory, which would otherwise
happen after local compilation. Finally, the local `exla` Makefiles are altered
to avoid undesired compilation.

Since we cannot guarantee that Mix triggers `exla_precompiled` compilation
before `exla`, the initialization occurs whenever the project information is
retrieved by running `mix.exs`. However, when a binary is already in place,
this comes down to a simple check and no further processing is done.

## Acknowledgments

Thanks to [@wojtekmach](https://github.com/wojtekmach) for exploring precompiled dependencies,
specifically for his work on [`cmark_precompiled`](https://github.com/wojtekmach/cmark_precompiled).

## Also

If this package happens to save you some time and CPU cycles, you can use some
of that to chill out and ponder with the buddy below.

![](https://images.unsplash.com/photo-1599889959407-598566c6e1f1?ixlib=rb-1.2.1&auto=format&fit=crop&w=700&q=80)
