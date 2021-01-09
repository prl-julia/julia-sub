# Julia Subtyping

[![Build Status](https://github.com/julbinb/julia-sub/workflows/CI/badge.svg)](https://github.com/julbinb/julia-sub/actions?query=workflow%3ACI+branch%3Amain)
[![codecov.io](http://codecov.io/github/julbinb/julia-sub/coverage.svg?branch=main)](http://codecov.io/github/julbinb/julia-sub?branch=main)

## Repository Organization

* [`README.md`](README.md) this file

## Analysis of lower bounds

As of Julia 1.5.3, there are only two accepted patterns of lower bounds:

1. `where T >: Int`
2. `where Int <: T <: Number`

Everything else (e.g. `where Int <: T`) doesn't work,
and [`test/lb-analysis.jl`](test/lb-analysis.jl) tests for that
in the tests set `"lb-analysis :: type bounds format"`.

The two patterns can be found in `extractLowerBound` function,
[`src/lb-analysis/process-code.jl`](src/lb-analysis/process-code.jl).

## Dependencies

* [Julia](https://julialang.org/) with the following packages:
  - `MacroTools` for parsing and expression walking utilities
  - `Multisets` for counting lower bounds

???
  - `JSON`
  - `ArgParse`
