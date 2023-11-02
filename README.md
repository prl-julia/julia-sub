# Julia Subtyping

[![Build Status](https://github.com/julbinb/julia-sub/workflows/CI/badge.svg)](https://github.com/julbinb/julia-sub/actions?query=workflow%3ACI+branch%3Amain)
[![codecov.io](http://codecov.io/github/julbinb/julia-sub/coverage.svg?branch=main)](http://codecov.io/github/julbinb/julia-sub?branch=main)

Currently, this project contains
empirical evaluation to support a restriction on Julia types
to provide for decidable subtyping for the Julia language.

Thus, we need to analyze type annotations used in Julia programs to see
if they satisfy a wildcards-like restriction
(there is also an analysis of scoping, lower bounds, lower+upper bounds).

**Note.** Some annotations that do not literally correspond to the restriction
from JB's thesis proposal/paper on decidable subtyping are not reported.
In particular, cases like `Tuple{Ref{T}} where T` are not reported because
they are trivially equivalent to `Tuple{Ref{T} where T}`.

## Static analysis of types

### Type annotations

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

We collect method type signatures and all other type annotations to the right
of `::`, which includes type assertions and types of fields.

**Note.** `MacroTools.jl` package has a handy function `isdef` to check
for function definitions, but it seems to
[always return true](https://github.com/FluxML/MacroTools.jl/issues/172).
~~We can use that to process method signatures.~~
- `longdef` turns all functions into long forms, including nested expressions
- `splitdef` conveniently processes any function definition form
  (short, long, anonymous) except for the do-notation

But we also want to collect information from nested function definitions
and stand-alone type assertions.
This is done manually with `@capture`.

### Type declarations

We collect all user-defined type declarations and record the declaration
itself and its declared supertype.
Then, we check whether they satisfy use-site variance when treated as complete
types. For example, `Foo{X, Y<:Ref{X}}` is analyzed as
`Foo{X, Y} where Y<:Ref{X} where X`.
Decidable subtyping doesn't require type declarations to satisfy use-site
variance, but it is a nice indicator of the complexity.


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
    - [`lib.jl`](src/types-analysis/lib.jl)
      main file combining everything related to the analysis
    - [`data.jl`](src/types-analysis/data.jl)
      data types used for the analysis
    - [`types-extract.jl`](src/types-analysis/types-extract.jl)
      extraction of type annotations
    - [`typedecls-extract.jl`](src/types-analysis/typedecls-extract.jl)
      extraction of type declarations
    - [`type-analyze.jl`](src/types-analysis/type-analyze.jl)
      analysis of type annotations
    - [`typedecl-analyze.jl`](src/types-analysis/typedecl-analyze.jl)
      analysis of type declarations
    - [`pkg-process.jl`](src/types-analysis/pkg-process.jl)
      processing of packages:
      extraction of type annotations and declarations into a CSV,
      an analysis of type annotations and declarations read from a CSV
      and saving interesting results into another CSV
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

* [JuliaPkgsList.jl](https://github.com/julbinb/JuliaPkgsList.jl)
* [JuliaPkgDownloader.jl](https://github.com/julbinb/JuliaPkgDownloader.jl)


**Getting packages data:**

Assumes `../utils/JuliaPkgsList.jl` and `../utils/JuliaPkgDownloader.jl`.
- For both packages, run `init-script.jl` first.
- `JuliaPkgsList.jl` should be "patched" with an empty `data/excluded.txt` file
to make it easier to track which entries are invalid 
(since the file is outdated now anyway).

**Note.** Sometimes because of network issues, some packages are not downloaded.
If in the case of all packages, the number of failed packages is > 50,
run downloading again.
Several dozen packages will remain broken for other reasons.

```
$ ../utils/JuliaPkgsList.jl/gen-pkgs-list.jl 100 -p data/julia-pkgs-info.json --name --includeversion --includeuuid -o data/pkgs-list/top-pkgs-list.txt

$ ../utils/JuliaPkgsList.jl/gen-pkgs-list.jl 0 -p data/julia-pkgs-info.json --name --includeversion --includeuuid -o data/pkgs-list/all-pkgs-list.txt

$ julia -p 32 ../utils/JuliaPkgDownloader.jl/download-pkgs.jl -s data/pkgs-list/100-top-pkgs-list.txt -d data/100

$ julia -p 32 ../utils/JuliaPkgDownloader.jl/download-pkgs.jl -s data/pkgs-list/all-pkgs-list.txt -d data/all
```


## Running type annotations analysis

**Note.** Output and error streams are redirected to a file.
To print to the terminal, remove `> data...`

To extract type annotations:

```
$ julia -p 32 types-extract.jl data/100 data/ta-info/100 > data/ta-info/log-extract-100.txt 2>&1

$ julia -p 32 types-extract.jl data/all data/ta-info/all > data/ta-info/log-extract-all.txt 2>&1
```

To analyze type annotations:

```
$ julia -p 32 types-analyze.jl data/ta-info/100 > data/ta-info/log-analysis-100.txt 2>&1

$ julia -p 32 types-analyze.jl data/ta-info/all > data/ta-info/log-analysis-all.txt 2>&1
```


## Adding more analyses

To extend the output CSV of the analysis and have a new CSV with 
types of interest:

- In `src/types-analysis/pkg-process.jl`:
  + extend `ANALYSIS_COLS_ANNS_NOERR`
  + in `analyzePkgTypeAnns`, 
    * extend `failedResult`
    * extend `dfta`
    * add a `df*` var and extend the for-loop right after
    * extend the resulting `Dict`
  + in `getTypeAnnsAnalyses`, extend `map` in `varsAnalyses`
  + extend `ANALYSIS_COLS_DECLS`
  + in `analyzePkgTypeDecls`, 
    * extend `failedResult`
    * extend `dftd`
    * add a `df*` var and extend the for-loop right after
    * extend the resulting `Dict`
  + in `addTypeDeclsAnalysis!`, extend `newCols`
  + in `analyzeTypeDecl`, extend the resulting array 
    and increment in `fill`
  + in `analyzePkgTypesAndSave2CSV`, 
    * extend both `combineVCat!`
    * add a `CSV.write`

- In tests, make sure to add `isfile` in `pkg-process.jl` for new CSV files.
  Furthermore, manually check that necessary annotations/declarations are 
  reported, as it is easy to make mistakes when copying stuff
  in dataframe-related code...

---

[Old README from 2021](notes/2021-notes.md)
