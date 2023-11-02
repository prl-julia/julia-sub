# README from 2021

- We know that Julia subtyping is undecidable.
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

