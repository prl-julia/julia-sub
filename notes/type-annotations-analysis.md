# Unsupported type annotations

```julia
# false positive, package ForneyLab.jl
# src/algorithms/posterior_factorization.jl
Tuple{
    Vararg{
        Union{
            T, Set{T}, Vector{T}
        } where T <: Variable
    }, Any}

# false positive (semantically), package Tries.jl
# src/Tries.jl
Tuple{
    Vararg{
        Pair{NTuple{N, K}, T} where N
    }
} where T where K

# false positive (semantically), package Tries.jl
# src/Tries.jl
Tuple{
    Vararg{
        Pair{NTuple{N, K}, <:Any} where N
    }
} where K

# false positive (semantically), package Muon.jl
# src/alignedmapping.jl
Dict{
    K,
    Union{
        AbstractArray{<:Number}, 
        AbstractArray{Union{Missing, T}} where T <: Number, 
        DataFrame
    }
}

# true positive, package Alicorn.jl
# test/Utils/UtilsTests.jl 
Array{
    Tuple{T, Array{T, N} where N, Bool} where T
}

# true positive, package UnitfulEquivalences.jl
# src/UnitfulEquivalences.jl
Tuple{
    Type{
        Union{
            Quantity{T, D, U}, 
            Level{L, S, Quantity{T, D, U}} where {L, S}
        } where {T, U}
    }} where D
```

## ForneyLab.jl

Types are actually equivalent (`Number` instead of `Variable`):

```julia
julia> t1 = Tuple{Vararg{Union{Number, Set{<:Number}, Vector{<:Number}}}}
Tuple{Vararg{Union{Number, Set{<:Number}, Vector{<:Number}}}}

julia> t2 = Tuple{Vararg{Union{T, Set{T}, Vector{T}} where T<:Number}}
Tuple{Vararg{Union{Set{T}, Vector{T}, T} where T<:Number}}

julia> t1 == t2
true
```

Make sure the code is used:

```julia
function PosteriorFactorization(args::Vararg{Union{T, Set{T}, Vector{T}} where T<:Variable}; ids=Symbol[])
		@info "inside PosteriorFactorization"

    pfz = PosteriorFactorization()
    isempty(ids) || (length(ids) == length(args)) || error("Length of ids must match length of posterior factor arguments")
    for (i, arg) in enumerate(args)
        if isempty(ids)
            PosteriorFactor(arg, id=generateId(PosteriorFactor))
        else        
            PosteriorFactor(arg, id=ids[i])
        end
    end

    # Verify that all stochastic edges are covered by a posterior factor
    uncovered_variables = uncoveredVariables(pfz)
    isempty(uncovered_variables) || error("Edges for stochastic variables $([var.id for var in uncovered_variables]) must be covered by a posterior factor")

    return pfz
end

(ForneyLab) pkg> test
     Testing ForneyLab
      Status `/tmp/jl_4Ge3ZP/Project.toml`
  [864edb3b] DataStructures v0.18.14
  ...
  [3f19e933] p7zip_jll v17.4.0+0 `@stdlib/p7zip_jll`
        Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading.
Precompiling project...
  1 dependency successfully precompiled in 3 seconds. 51 already precompiled.
     Testing Running tests...
WARNING: method definition for baz at /media/Research/julia-sub/data/unsupported-restriction/ForneyLab.jl-0.12.0/test/test_helpers.jl:89 declares type 
...
WARNING: method definition for baz at /media/Research/julia-sub/data/unsupported-restriction/ForneyLab.jl-0.12.0/test/test_helpers.jl:89 declares type variable C but does not use it.
[ Info: inside PosteriorFactorization
[ Info: inside PosteriorFactorization
[ Info: inside PosteriorFactorization
[ Info: inside PosteriorFactorization
[ Info: inside PosteriorFactorization
[ Info: inside PosteriorFactorization
[ Info: inside PosteriorFactorization
Test Summary: | Pass  Total     Time
ForneyLab     | 2237   2237  1m25.2s
     Testing ForneyLab tests passed 

```

Modify the code:

```julia
function PosteriorFactorization(args::Vararg{Union{Variable, Set{<:Variable}, Vector{<:Variable}}}; ids=Symbol[])
		@info "inside modified PosteriorFactorization"

    pfz = PosteriorFactorization()
    isempty(ids) || (length(ids) == length(args)) || error("Length of ids must match length of posterior factor arguments")
    for (i, arg) in enumerate(args)
        if isempty(ids)
            PosteriorFactor(arg, id=generateId(PosteriorFactor))
        else        
            PosteriorFactor(arg, id=ids[i])
        end
    end

    # Verify that all stochastic edges are covered by a posterior factor
    uncovered_variables = uncoveredVariables(pfz)
    isempty(uncovered_variables) || error("Edges for stochastic variables $([var.id for var in uncovered_variables]) must be covered by a posterior factor")

    return pfz
end

(ForneyLab) pkg> test
     Testing ForneyLab
      Status `/tmp/jl_UzRPR7/Project.toml`
  [864edb3b] DataStructures v0.18.14
  ...
  [3f19e933] p7zip_jll v17.4.0+0 `@stdlib/p7zip_jll`
        Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading.
Precompiling project...
  1 dependency successfully precompiled in 4 seconds. 51 already precompiled.
     Testing Running tests...
WARNING: method definition for baz at /media/Research/julia-sub/data/unsupported-restriction/ForneyLab.jl-0.12.0/test/test_helpers.jl:89 declares type variable A but does not use it.
...
WARNING: method definition for baz at /media/Research/julia-sub/data/unsupported-restriction/ForneyLab.jl-0.12.0/test/test_helpers.jl:89 declares type variable C but does not use it.
[ Info: inside modified PosteriorFactorization
[ Info: inside modified PosteriorFactorization
[ Info: inside modified PosteriorFactorization
[ Info: inside modified PosteriorFactorization
[ Info: inside modified PosteriorFactorization
[ Info: inside modified PosteriorFactorization
[ Info: inside modified PosteriorFactorization
Test Summary: | Pass  Total     Time
ForneyLab     | 2237   2237  1m22.4s
     Testing ForneyLab tests passed 
```

## Tries.jl (both examples)

Types are not equivalent but the restriction is a subtype:

```julia
julia> t1 = Tuple{
         Vararg{
           Pair{NTuple{N, K}, T} where N
         }
       } where T where K
Tuple{Vararg{Pair{Tuple{Vararg{K, N}}, T} where N}} where {K, T}

julia> t2 = Tuple{
         Vararg{
           Pair{NTuple{N, K}, T}
         } where N
       } where T where K
Tuple{Vararg{Pair{Tuple{Vararg{K, N}}, T}}} where {K, T, N}

julia> t1 == t2
true

julia> t3 = Tuple{Vararg{Pair{NTuple{N,K},<:Any} where N}} where {K}
Tuple{Vararg{Pair{Tuple{Vararg{K, N}}} where N}} where K

julia> t4 = Tuple{Vararg{Pair{NTuple{N,K},<:Any}} where N} where {K} 
Tuple{Vararg{Pair{Tuple{Vararg{K, N}}}}} where {N, K}

julia> t3 == t4
true
```

Make sure the code is used:

```julia
function Trie(values::Vararg{Pair{NTuple{N,K},T} where N}) where {K,T}
		@info "inside Trie #1"
    r = Trie{K,T}(missing, Dict{K,Trie{K,T}}())
    for (k,v) in values
        r[k...]=v
    end
    r
end

function Trie(values::Vararg{Pair{NTuple{N,K},<:Any} where N}) where {K}
		@info "inside Trie #2"
    r = Trie{K,Any}(missing, Dict{K,Trie{K,Any}}())
    for (k,v) in values
        r[k...]=v
    end
    r
end

(Tries) pkg> test
     Testing Tries
      Status `/tmp/jl_KyShJr/Project.toml`
⌅ [1520ce14] AbstractTrees v0.3.4
  ...
  [8dfed614] Test `@stdlib/Test`
        Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading.
Precompiling project...
  1 dependency successfully precompiled in 1 seconds. 1 already precompiled.
     Testing Running tests...
[ Info: inside Trie #2
[ Info: inside Trie #1
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
...
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
SubTrie{Symbol,String} @ :a, :b => "c"
└─ :d => "y"
Trie{Symbol,Int64} => 1
[ Info: inside Trie #1
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
...
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
Test Summary: | Pass  Broken  Total  Time
Tries.jl      |   43       1     44  3.7s
     Testing Tries tests passed 
```

Modify the code:

```julia
function Trie(values::Vararg{Pair{NTuple{N,K},T}} where N) where {K,T}
		@info "inside modified Trie #1"
    r = Trie{K,T}(missing, Dict{K,Trie{K,T}}())
    for (k,v) in values
        r[k...]=v
    end
    r
end

function Trie(values::Vararg{Pair{NTuple{N,K},<:Any}} where N) where {K}
		@info "inside modified Trie #2"
    r = Trie{K,Any}(missing, Dict{K,Trie{K,Any}}())
    for (k,v) in values
        r[k...]=v
    end
    r
end

(Tries) pkg> test
     Testing Tries
      Status `/tmp/jl_4xPP7s/Project.toml`
⌅ [1520ce14] AbstractTrees v0.3.4
  [666c268a] Tries v0.1.4 `/media/Research/julia-sub/data/unsupported-restriction/Tries.jl-0.1.4`
  [8dfed614] Test `@stdlib/Test`
      Status `/tmp/jl_4xPP7s/Manifest.toml`
⌅ [1520ce14] AbstractTrees v0.3.4
  [666c268a] Tries v0.1.4 `/media/Research/julia-sub/data/unsupported-restriction/Tries.jl-0.1.4`
  [2a0f44e3] Base64 `@stdlib/Base64`
  [b77e0a4c] InteractiveUtils `@stdlib/InteractiveUtils`
  [56ddb016] Logging `@stdlib/Logging`
  [d6f4376e] Markdown `@stdlib/Markdown`
  [9a3f8284] Random `@stdlib/Random`
  [ea8e919c] SHA v0.7.0 `@stdlib/SHA`
  [9e88b42a] Serialization `@stdlib/Serialization`
  [8dfed614] Test `@stdlib/Test`
        Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading.
Precompiling project...
  1 dependency successfully precompiled in 1 seconds. 1 already precompiled.
     Testing Running tests...
[ Info: inside modified Trie #2
[ Info: inside modified Trie #1
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
...
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
SubTrie{Symbol,String} @ :a, :b => "c"
└─ :d => "y"
Trie{Symbol,Int64} => 1
[ Info: inside modified Trie #1
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
...
WARNING: Wrapping `Vararg` directly in UnionAll is deprecated (wrap the tuple instead).
Test Summary: | Pass  Broken  Total  Time
Tries.jl      |   43       1     44  3.7s
     Testing Tries tests passed 
```

## Muon.jl

These tests failed on Julia 1.8.5:

```julia
@testset "HDF5 backed matrix" begin
    include("backed_matrix.jl")
end
```

So I commented them out.

Make sure the code is used (only for `alignedmapping` tests because 
other tests failed when the log was different):

```julia
struct AlignedMapping{T <: Tuple, K, R} <: AbstractAlignedMapping{
    T,
    K,
    Union{
        AbstractArray{<:Number},
        AbstractArray{Union{Missing, T}} where T <: Number,
        AbstractDataFrame,
    },
}
    ref::R # any type as long as it supports size()
    d::Dict{
        K,
        Union{
            AbstractArray{<:Number},
            AbstractArray{Union{Missing, T}} where T <: Number,
            DataFrame,
        },
    }
		
    function AlignedMapping{T, K}(r, d::AbstractDict{K}) where {T <: Tuple, K}
	    	@info "inside AlignedMapping"
        for (k, v) in d
            checkdim(T, v, r, k)
        end
        return new{T, K, typeof(r)}(r, d)
    end
end

(Muon) pkg> test
     Testing Muon
      Status `/tmp/jl_DttvFr/Project.toml`
  [a93c6f00] DataFrames v1.6.0
  ...
  [3f19e933] p7zip_jll v17.4.0+0 `@stdlib/p7zip_jll`
        Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading.
     Testing Running tests...
[ Info: inside AlignedMapping
...
[ Info: inside AlignedMapping
┌ Warning: `compress=9` keyword option is deprecated, use `deflate=9` instead
│   caller = setproperty!(p::HDF5.DatasetCreateProperties, name::Symbol, val::UInt8) at properties.jl:59
└ @ HDF5 ~/.julia/packages/HDF5/aiZLs/src/properties.jl:59
Test Summary:    | Pass  Total   Time
aligned mappings |   60     60  25.6s
     Testing Muon tests passed 
```

Modify the code:

```julia
struct AlignedMapping{T <: Tuple, K, R} <: AbstractAlignedMapping{
    T,
    K,
    Union{
        AbstractArray{<:Number},
        AbstractArray{T} where Missing <: T <: Union{Number,T},
        AbstractDataFrame,
    },
}
    ref::R # any type as long as it supports size()
    d::Dict{
        K,
        Union{
            AbstractArray{<:Number},
            AbstractArray{T} where Missing <: T <: Union{Number,T},
            DataFrame,
        },
    }
		
    function AlignedMapping{T, K}(r, d::AbstractDict{K}) where {T <: Tuple, K}
	    	@info "inside modified AlignedMapping"
        for (k, v) in d
            checkdim(T, v, r, k)
        end
        return new{T, K, typeof(r)}(r, d)
    end
end

(Muon) pkg> test
     Testing Muon
      Status `/tmp/jl_xrbdJd/Project.toml`
  [a93c6f00] DataFrames v1.6.0
  ...
  [3f19e933] p7zip_jll v17.4.0+0 `@stdlib/p7zip_jll`
        Info Packages marked with ⌅ have new versions available but compatibility constraints restrict them from upgrading.
Precompiling project...
  1 dependency successfully precompiled in 5 seconds. 48 already precompiled.
     Testing Running tests...
[ Info: inside modified AlignedMapping
...
[ Info: inside modified AlignedMapping
┌ Warning: `compress=9` keyword option is deprecated, use `deflate=9` instead
│   caller = setproperty!(p::HDF5.DatasetCreateProperties, name::Symbol, val::UInt8) at properties.jl:59
└ @ HDF5 ~/.julia/packages/HDF5/aiZLs/src/properties.jl:59
Test Summary:    | Pass  Total   Time
aligned mappings |   60     60  27.1s
     Testing Muon tests passed 
```

Tests work if logging is turned off.

## Alicorn.jl

Make sure the code is used:

```julia
function _getExamplesFor_isElementOf()
    examples::Array{ Tuple{T, Array{T,N} where N, Bool} where T } = [
    ("a", ["a" "b" "c" "d"], true),
    (1, [2 3; 4 5], false),
    ]
    @info "inside _getExamplesFor_isElementOf"
    return examples
end

(Alicorn) pkg> test
     Testing Alicorn
      Status `/tmp/jl_s7lWyB/Project.toml`
  [80a53053] Alicorn v1.0.0 `/media/Research/julia-sub/data/unsupported-restriction/Alicorn-1.0.0`
  [9a3f8284] Random `@stdlib/Random`
  [8dfed614] Test `@stdlib/Test`
      Status `/tmp/jl_s7lWyB/Manifest.toml`
  [80a53053] Alicorn v1.0.0 `/media/Research/julia-sub/data/unsupported-restriction/Alicorn-1.0.0`
  [2a0f44e3] Base64 `@stdlib/Base64`
  [b77e0a4c] InteractiveUtils `@stdlib/InteractiveUtils`
  [56ddb016] Logging `@stdlib/Logging`
  [d6f4376e] Markdown `@stdlib/Markdown`
  [9a3f8284] Random `@stdlib/Random`
  [ea8e919c] SHA v0.7.0 `@stdlib/SHA`
  [9e88b42a] Serialization `@stdlib/Serialization`
  [8dfed614] Test `@stdlib/Test`
     Testing Running tests...
[ Info: inside _getExamplesFor_isElementOf
Test Summary: | Pass  Total  Time
Utils         |   45     45  1.4s
Test Summary: | Pass  Total  Time
Units         |  220    220  0.9s
Test Summary: | Pass  Total  Time
Dimension     |   18     18  0.1s
Test Summary: | Pass  Total     Time
Quantities    |  617    617  1m05.3s
Test Summary:  | Pass  Total  Time
PrettyPrinting |   13     13  2.4s
     Testing Alicorn tests passed 
```

Modify the code:

```julia
function _getExamplesFor_isElementOf()
    examples::Array{ Tuple{Any, Array, Bool} } = [
    ("a", ["a" "b" "c" "d"], true),
    (1, [2 3; 4 5], false),
    ]
    @info "inside modified _getExamplesFor_isElementOf"
    return examples
end

(Alicorn) pkg> test
     Testing Alicorn
      Status `/tmp/jl_MYJUxt/Project.toml`
  [80a53053] Alicorn v1.0.0 `/media/Research/julia-sub/data/unsupported-restriction/Alicorn-1.0.0`
  [9a3f8284] Random `@stdlib/Random`
  [8dfed614] Test `@stdlib/Test`
      Status `/tmp/jl_MYJUxt/Manifest.toml`
  [80a53053] Alicorn v1.0.0 `/media/Research/julia-sub/data/unsupported-restriction/Alicorn-1.0.0`
  [2a0f44e3] Base64 `@stdlib/Base64`
  [b77e0a4c] InteractiveUtils `@stdlib/InteractiveUtils`
  [56ddb016] Logging `@stdlib/Logging`
  [d6f4376e] Markdown `@stdlib/Markdown`
  [9a3f8284] Random `@stdlib/Random`
  [ea8e919c] SHA v0.7.0 `@stdlib/SHA`
  [9e88b42a] Serialization `@stdlib/Serialization`
  [8dfed614] Test `@stdlib/Test`
     Testing Running tests...
[ Info: inside modified _getExamplesFor_isElementOf
Test Summary: | Pass  Total  Time
Utils         |   45     45  1.4s
Test Summary: | Pass  Total  Time
Units         |  220    220  0.9s
Test Summary: | Pass  Total  Time
Dimension     |   18     18  0.1s
Test Summary: | Pass  Total     Time
Quantities    |  617    617  1m01.8s
Test Summary:  | Pass  Total  Time
PrettyPrinting |   13     13  2.2s
     Testing Alicorn tests passed 
```

## UnitfulEquivalences.jl

Make sure the code is used:

```julia
dimtype(::Type{Union{Quantity{T,D,U}, Level{L,S,Quantity{T,D,U}} where {L,S}} where {T,U}}) where D = begin
	@info "inside dimtype"
	typeof(D)
end

(UnitfulEquivalences) pkg> test
     Testing UnitfulEquivalences
      Status `/tmp/jl_2RE8T0/Project.toml`
  [1986cc42] Unitful v1.15.0
  ...
  [8e850b90] libblastrampoline_jll v5.1.1+0 `@stdlib/libblastrampoline_jll`
Precompiling project...
  1 dependency successfully precompiled in 1 seconds. 6 already precompiled.
     Testing Running tests...
Test Summary: | Pass  Total  Time
Conversion    |   54     54  4.4s
[ Info: inside dimtype
[ Info: inside dimtype
[ Info: inside dimtype
[ Info: inside dimtype
[ Info: inside dimtype
┌ Warning: macroexpand no longer throws a LoadError so `@test_throws LoadError ...` is deprecated and passed without checking the error type!
│   caller = macro expansion at runtests.jl:106 [inlined]
└ @ Core /media/Research/julia-sub/data/unsupported-restriction/UnitfulEquivalences.jl-0.2.0/test/runtests.jl:106
┌ Warning: macroexpand no longer throws a LoadError so `@test_throws LoadError ...` is deprecated and passed without checking the error type!
│   caller = macro expansion at runtests.jl:107 [inlined]
└ @ Core /media/Research/julia-sub/data/unsupported-restriction/UnitfulEquivalences.jl-0.2.0/test/runtests.jl:107
Test Summary: | Pass  Total  Time
@eqrelation   |   10     10  1.6s
Test Summary: | Pass  Total  Time
MassEnergy    |    2      2  0.2s
Test Summary: | Pass  Total  Time
Spectral      |   99     99  0.6s
Test Summary: | Pass  Total  Time
Thermal       |    4      4  0.5s
     Testing UnitfulEquivalences tests passed 
```

I didn't find a way to refactor the code.

## Vararag

For some reason:
```julia
julia> tx = Tuple{Vararg{Ref{T}} where T}
Tuple{Vararg{Ref}}

julia> ty = Tuple{Vararg{Ref{T} where T}}
Tuple{Vararg{Ref}}

julia> tx == ty
true

julia> tz = Tuple{Vararg{Ref{T}}} where T
Tuple{Vararg{Ref{T}}} where T

julia> ty == tz
false
```

All three should be equivalent. Ah, no, it makes sense!
```julia
  julia> f(::Vararg{Ref{T}} where T) = 0
f (generic function with 1 method)

julia> f(::Vararg{Ref{T}}) where T = 0
f (generic function with 2 methods)

julia> f(::Vararg{Ref{T}}) where T = 1
f (generic function with 2 methods)

julia> f(Ref{Int}(), Ref{Bool}())
0

julia> f(Ref{Int}(), Ref{Int}())
1
```

So, it's a special case.

# LOC

julia@prl-julia:~/subtyping/julia-sub/data$ cloc all/
  354991 text files.
  313277 unique files.                                          
   94402 files ignored.

3 errors:
Line count, exceeded timeout:  all/DocumenterEpub.jl/res/mathjax/sre/sre_browser.js
Line count, exceeded timeout:  all/Franklin.jl/docs/_libs/lunr/lunr_index.js
Line count, exceeded timeout:  all/TuringPatterns.jl/patternshop/mithril.js

github.com/AlDanial/cloc v 1.82  T=1662.69 s (157.4 files/s, 31818.8 lines/s)
---------------------------------------------------------------------------------------
Language                             files          blank        comment           code
---------------------------------------------------------------------------------------
Julia                                172024        3830817        1937753       19476938
SVG                                   2523          10256          14639        5175925
JSON                                  3114            381              0        2364957
Markdown                             36873         698590             37        2214366
XML                                    284           1761           1084        1774545
TOML                                 19517         275899           3982        1388567
HTML                                  1777         102745           5928        1103924
C/C++ Header                           525          17610          63813         984527
YAML                                 12515          43152          29049         837986
JavaScript                            1231          72080         106337         432377
CSS                                    784          33747           7177         428157
Jupyter Notebook                      2222              2        6605218         405558
RobotFramework                         276            186             30         331558
Lisp                                   538         119214            373         221869
TeX                                    409          12708           7973         217032
MATLAB                                 586           5081          28297         204632
Python                                1156          19935          19428         201734
MUMPS                                   53              8              1         189405
C                                      452          23321          66837         133027
C++                                    301          14627           5944          62003
Rust                                   287           2090           7887          57582
reStructuredText                      1116          27783          18919          47536
GraphQL                                  4           9076              7          47271
Oracle Forms                             1              0              0          38016
QML                                     71            800            340          31978
Fortran 77                              46            498          27790          29923
Bourne Shell                          1013           3516           4527          21697
Fortran 90                              35           1797           5783          18104
R                                      390           2991           1854          15017
Protocol Buffers                        72           2553           8507          12654
Sass                                   142           1422           1024          10269
ANTLR Grammar                           37            830              0           7628
make                                   204           1746            512           7078
Ruby                                    13             41             20           6309
CUDA                                    50           1405           1347           5692
INI                                    133           1120             11           5670
Cucumber                                38            550            227           5565
CMake                                  121           1154            878           4736
ColdFusion                               1              2              0           3840
TypeScript                              48            539           4151           3803
GLSL                                    49            685            896           3565
Scala                                   54            626            244           3398
DOS Batch                               36            409             39           2449
Bourne Again Shell                     101            662            812           2399
Mustache                                18            116              0           2046
LESS                                    14             34             44           1758
Perl                                    14            134            152           1614
Vuejs Component                          9            153             15           1596
Verilog-SystemVerilog                   40            217            395           1436
Windows Module Definition               11            134              0           1341
Mathematica                             11            261            851           1316
Dockerfile                              76            344            299           1233
Glade                                    6              0              6           1150
SAS                                     12             18              9           1115
Go                                      10            140             67            808
Rmd                                      8            279            403            615
Teamcenter mth                           1             75              0            566
Unity-Prefab                            65              2              0            441
DTD                                      2             14              0            419
IDL                                      8             57            241            401
m4                                       2             63             26            386
Stata                                    7             68             22            382
Java                                     2             88             99            376
C Shell                                 16             52             44            331
SQL                                     15             29              6            313
OpenCL                                   8             54             75            293
Smarty                                   3              0              0            289
Expect                                  20            112              0            277
Solidity                                 9             25              0            225
Arduino Sketch                           2             36             14            156
Objective C++                            1              1              0            150
Scheme                                   3             19              0            106
GDScript                                 7            112           1272             99
PO File                                  4             34             16             98
sed                                      2             33             63             75
Lua                                      3              6             18             67
Tcl/Tk                                   2             19              4             58
Nix                                      5              5              2             57
Maven                                    2              0              3             51
F#                                       4             22             18             50
XSD                                      1              7              7             48
AutoHotkey                               1             14              3             46
Freemarker Template                      1             11              0             46
Fortran 95                               1              0              0             44
vim script                               4              1              2             38
Qt                                       1              0              0             36
diff                                     1              9             13             33
AsciiDoc                                 3             15              0             31
Gencat NLS                               7              7              0             30
Oracle PL/SQL                            1              0              0             29
PHP                                      1              3             40             29
PowerShell                               3              7              1             26
XSLT                                     1              0              0             25
Objective C                              1              4              0             19
Groovy                                   2              3              0             16
HCL                                      1              8              0             15
NAnt script                              1              3              0             15
SparForte                                2              0              0             13
Fish Shell                               1              4              1             11
XHTML                                    1              3              0              9
Harbour                                  1              0              0              7
Clojure                                  1              3              2              4
zsh                                      2              0              0              4
---------------------------------------------------------------------------------------
SUM:                                261683        5347273        8993908       38563534
---------------------------------------------------------------------------------------



# Subtyping

`SymFourthOrderTensorValue{D, T, L}` in Gridlab has some bad uses, but they seem
to be related to dimensions.

723 packages have bad declarations out of 9000.


## Scoping restriction

- `Tuple{Type{Union{T, Missing}}} where T`
- `Tuple{OneHotLike{X1, L} where X1 <: Any, Vararg{OneHotLike{X2, L} where X2 <: Any}, Int} where L`
- `Tuple{Type{ReshapedDistribution{<:Any, <:ValueSupport, D}}} where D`

Varargs are special, so it's probably ok.


## Impredicative non use-site variance

```julia
Tuple{
    Type{
        Union{
            Quantity{T, D, U},
            Level{L, S, Quantity{T, D, U}} where {L, S}
        } where {T, U}
    }
} where D
```

## Misc

Some expressions are mistaken for function definition, e.g. Catlab
`(x,y) where (x,y,z) -> ...` is considered `Tuple{Any, Any} where (x,y,z)`

All

```
┌ Info: Total statnames:
│   v =
│    7-element Vector{Symbol}:
│     :Error
│     :Warning
│     :VarCnt
│     :HasWhere
│     :VarsUsedOnce
│     :UseSiteVariance
└     :RestrictedScope
┌ Info: Total statsums:
│   v =
│    7-element Vector{Int64}:
│         962
│       17403
│      339925
│      203374
│     1219503
│     1236999
└     1265636
┌ Info: Total badPkg:
└   v = 43
┌ Info: Total goodPkg:
└   v = 7572
┌ Info: Total totalta:
└   v = 1272892
```

I.e. 7256 types that do not satisfy the constraint out of 203374


Top-100

```
┌ Info: Total statnames:
│   v =
│    7-element Vector{Symbol}:
│     :Error
│     :Warning
│     :VarCnt
│     :HasWhere
│     :VarsUsedOnce
│     :UseSiteVariance
└     :RestrictedScope
┌ Info: Total statsums:
│   v =
│    7-element Vector{Int64}:
│        56
│      1530
│     19858
│     12089
│     79391
│     80554
└     81931
┌ Info: Total badPkg:
└   v = 0
┌ Info: Total goodPkg:
└   v = 100
┌ Info: Total totalta:
└   v = 82359
```


Top-10

```
┌ Info: Total statnames:
│   v =
│    8-element Vector{Symbol}:
│     :Error
│     :Warning
│     :VarCnt
│     :HasWhere
│     :VarsUsedOnce
│     :UseSiteVariance
│     :ImprUseSiteVariance
└     :RestrictedScope
┌ Info: Total statsums:
│   v =
│    8-element Vector{Int64}:
│        2
│       80
│     1953
│     1122
│     8242
│     8320
│     8508
└     8506
┌ Info: Total badPkg:
└   v = 0
┌ Info: Total goodPkg:
└   v = 10
┌ Info: Total totalta:
└   v = 8510


```


```

Tuple{
    (
        (Base.ReshapedArray{
            var"##ANON_TV#293", 
            var"##ANON_TV#294", 
            var"##ANON_TV#295"
        } where var"##ANON_TV#293" <: Any) 
        where var"##ANON_TV#294" <: Any)
    where var"##ANON_TV#295" <: (OneHotArray{var"##ANON_TV#296", L} where var"##ANON_TV#296" <: Any)
} where L




Tuple{OneHotLike{<:Any, L}, Vararg{OneHotLike{<:Any, L}}, Int} where L

Tuple{
    OneHotLike{T1, L} where T1 <: Any, 
    Vararg{OneHotLike{T2, L} where T2 <: Any}, 
    Int
} where L


```