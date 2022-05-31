# Julia Subtyping

[![Build Status](https://github.com/julbinb/julia-sub/workflows/CI/badge.svg)](https://github.com/julbinb/julia-sub/actions?query=workflow%3ACI+branch%3Amain)
[![codecov.io](http://codecov.io/github/julbinb/julia-sub/coverage.svg?branch=main)](http://codecov.io/github/julbinb/julia-sub?branch=main)

Developing decidable subtyping for the Julia language.

- Lower bounds aren't the only reason for the undecidability of Julia subtyping.
- We need to analyze type annotations used in Julia programs to see if they
  satisfy either the scoping or wildcards-like restriction.

## Static analysis of types

Usually, type annotations appear after `::` in the code:
- as a part of the method signature
  (either as an argument or return type annotation),
- as a type assertion in the method body.

When methods are generic, there can be an extra `where` sequence
in the method signature, outside of the argument list.

**Examples:**

- `foo(x :: Int) :: Bool`
- `foo(x :: Vector{T} where T)`
- `foo(x :: T, xs :: Vector{T}) where T`
- `x :: Int`

**Note.** `MacroTools.jl` package has a handy function `isdef` to check
for function definitions, but it seems to
[always return true](https://github.com/FluxML/MacroTools.jl/issues/172).
~~We can use that to process method signatures.~~

But we also want to collect information from nested function definitions
and stand-alone type assertions.

- `longdef` turns all functions into long forms, including nested expressions
- `splitdef` conveniently processes any function definition form
  (short, long, anonymous) except for the do-notation


## Repository Organization

- [``]()

- [`README.md`](README.md) this file

- [`init-script.jl`](init-script.jl) to install dependencies into
  the global Julia environment
- [`types-extract.jl`](types-extract.jl) script for extracting type annotations
  from source code of packages
- [`types-analyze.jl`](types-analyze.jl) script for analyzing extracted
  type annotations

- [`run-tests.jl`](run-tests.jl) convenience script for running the tests
  (`$ julia run-tests.jl` or `$ ./run-tests.jl`)

- [`src`](src) source code
  - [`JuliaSub.jl`](src/JuliaSub.jl) main module
  - [`lb-analysis`](src/lb-analysis) analysis of lower bounds
    - [`lib.jl`](src/lb-analysis/lib.jl)
      main file combining everything related to the analysis
    - [`data.jl`](src/lb-analysis/data.jl)
      data types used for the analysis
    - [`process-code.jl`](src/lb-analysis/process-code.jl)
      extraction and counting lower bounds in Julia expressions
    - [`process-text.jl`](src/lb-analysis/process-text.jl)
      textual and parse-based analysis of lower bounds in text 
    - [`process-pkgs.jl`](src/lb-analysis/process-pkgs.jl)
      lower-bounds analysis of files, packages, and folders with packages
  - [`types-analysis`](src/types-analysis) analysis of type annotations
  - [`utils`](src/utils) auxiliary
    - [`lib.jl`](src/utils/lib.jl)
      main file combining all utilities
    - [`equality.jl`](src/utils/equality.jl)
      generic definition of structural equality
    - [`file-system.jl`](src/utils/file-system.jl)
      file system helpers
    - [`multiset.jl`](src/utils/multiset.jl)
      multiset merging via adding frequencies (instead of default max)
    - [`parsing.jl`](src/utils/parsing.jl)
      helpers for parsing Julia files
    - [`status-info.jl`](src/utils/status-info.jl) custom logging

- [`lb-analysis.jl`](lb-analysis.jl) script that performs
  a complete analysis of lower bounds in the given folder with Julia packages

- [`Project.toml`](Project.toml) dependencies 


## Dependencies

* [Julia](https://julialang.org/) with the following packages:
  - [`MacroTools`](https://github.com/FluxML/MacroTools.jl)
    for working with Julia AST  
    *Note.* Another package that could have been useful is
    [`Match`](https://github.com/kmsquire/Match.jl)
  - [`Multisets`](https://github.com/scheinerman/Multisets.jl)
    for counting frequencies of lower bounds
  - [`DataStructures`](https://github.com/JuliaCollections/DataStructures.jl)
    for linked lists, to efficiently collect annotations
  - `CSV.jl`
  - `DataFrames.jl`
  - `Distributed.jl`
  - `ArgParse`

???
  - `JSON`

## Running type annotations analysis

To extract type annotations:

```
$ julia -p 32 types-extract.jl ../data/100 ../data/ta-info/100 > ../data/ta-info/log-extract-100.txt 2>&1

$ julia -p 32 types-extract.jl ../data/all ../data/ta-info/all > ../data/ta-info/log-extract-all.txt 2>&1
```

To analyze type annotations:

```
$ julia -p 32 types-anaylze.jl ../data/ta-info/100 > ../data/ta-info/log-analysis-100.txt 2>&1

$ julia -p 32 types-anaylze.jl ../data/ta-info/100 > ../data/ta-info/log-analysis-100.txt 2>&1
```

**Getting packages data:**

```
$ JuliaPkgsList.jl/gen-pkgs-list.jl 100 -p data/julia-pkgs-info.json --name --includeversion --includeuuid -o data/pkgs-list/top-pkgs-list.txt

$ JuliaPkgsList.jl/gen-pkgs-list.jl 0 -p data/julia-pkgs-info.json --name --includeversion --includeuuid -o data/pkgs-list/all-pkgs-list.txt

$ julia -p 32 JuliaPkgDownloader.jl/download-pkgs.jl -s data/pkgs-list/100-top-pkgs-list.txt -d data/100

$ julia -p 32 JuliaPkgDownloader.jl/download-pkgs.jl -s data/pkgs-list/all-pkgs-list.txt -d data/all
```

---

# Notes from 2021

- We know that Julia subtyping is undecidable due to lower bounds.
- Can we restrict lower bounds to make subtyping decidable,
  at the same time allowing all the practical uses of lower bounds
  in the existing Julia code?

Using static analysis, we find uses of lower bounds in Julia packages
and manually inspect them.


## Static analysis of lower bounds

As of Julia 1.5.3, there are only two accepted patterns of lower bounds
in the full form of where-types,

1. `where T >: Int`
2. `where Int <: T <: Number`

as well as one shorthand form `Vector{>:Int}`
(which means `Vector{T} where T>:Int`).

Everything else (e.g. `where Int <: T`) doesn't work,
and [`test/lb-analysis.jl`](test/lb-analysis.jl) tests for that
in the tests set `"lb-analysis :: type bounds format"`.

The three patterns can be found in `extractLowerBound` function,
[`src/lb-analysis/process-code.jl`](src/lb-analysis/process-code.jl).

**Note.** Not all lower bounds that we find are in function definitions
because we don't specifically match `where`, just `T >: LB`.
Thus, we also find run-time checks for lower bounds.

### Getting the data

Assuming the directory structure:
```
.
|
-- julia-sub
-- utils
     |
     -- JuliaPkgsList.jl
     -- JuliaPkgDownloader
```

**Old stuff below**

and `jl-wa` with a clonning script

```
$ ../../utils/JuliaPkgsList.jl/gen-pkgs-list.jl 0 -o pkgs-list/pkgs-list.txt -r

$ julia -p 8 ../../jl-wa/src/utils/clone.jl -s pkgs-list/pkgs-list.txt -d pkgs/4886/
```

### Running the analysis

```
$ julia analysis-script.jl <pkgs>
```

where `<pkgs` is a folder with Julia packages.

lia analysis-script.jl <pkgs>
```

where `<pkgs` is a folder with Julia packages.

