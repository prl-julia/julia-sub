# Julia Subtyping

[![Build Status](https://github.com/julbinb/julia-sub/workflows/CI/badge.svg)](https://github.com/julbinb/julia-sub/actions?query=workflow%3ACI+branch%3Amain)
[![codecov.io](http://codecov.io/github/julbinb/julia-sub/coverage.svg?branch=main)](http://codecov.io/github/julbinb/julia-sub?branch=main)

Developing decidable subtyping for the Julia language.

- We know that Julia subtyping is undecidable due to lower bounds.
- Can we restrict lower bounds to make subtyping decidable,
  at the same time allowing all the practical uses of lower bounds
  in the existing Julia code?

Using static analysis, we find uses of lower bounds in Julia packages
and manually inspect them.


## Static analysis of lower bounds

As of Julia 1.5.3, there are only two accepted patterns of lower bounds:

1. `where T >: Int`
2. `where Int <: T <: Number`

Everything else (e.g. `where Int <: T`) doesn't work,
and [`test/lb-analysis.jl`](test/lb-analysis.jl) tests for that
in the tests set `"lb-analysis :: type bounds format"`.

The two patterns can be found in `extractLowerBound` function,
[`src/lb-analysis/process-code.jl`](src/lb-analysis/process-code.jl).

**Note.** Not all lower bounds that we find are in function definitions
because we don't specificly match `where`, just `T >: LB`.
Thus, we also find run-time checks for lower bounds.

## Repository Organization

- [``]()

- [`README.md`](README.md) this file

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

- [`Project.toml`](Project.toml) dependencies 


## Dependencies

* [Julia](https://julialang.org/) with the following packages:
  - [`MacroTools`](https://github.com/FluxML/MacroTools.jl)
    for working with Julia AST  
    *Note.* Another package that could have been useful is
    [`Match.jl`](https://github.com/kmsquire/Match.jl)
  - [`Multisets`](https://github.com/scheinerman/Multisets.jl)
    for counting frequencies of lower bounds

???
  - `JSON`
  - `ArgParse`
