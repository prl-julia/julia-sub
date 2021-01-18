# Analysis of lower bounds in  registered Julia packages

As of January 2020, there are 50/4838 packages
that use lower bounds according to the static analysis.

The most popular lower bound is `Missing`: 116 uses
(but turned out that a lot of them are from run-time checks).

## Bounds analysis

So far, the only interesting case seems to be `T => 2`.

`AxisIndices.jl` with `CheckedAxisLengths => 2` is a neat case where
singletons in a union are used as flags.

`HomotopyContinuation.jl` use `>: Tuple`, and `Tuple` is not concrete.
The use is weird, and we also found suspicious behavior related to Tuple
lower bounds, so submitted an [issue](https://github.com/JuliaLang/julia/issues/39277).

`DataValues.jl` uses `>: Any`, which doesn't seem to be different from `Any`,
so we asked why in an [issue](https://github.com/queryverse/DataValues.jl/issues/82).

### `Missing` 116, `DateTime` 1, `Float64` 1, `CategoricalValue{String, Int32}` 1

Seems to be used for parsing and in combination with `Type{T}`, e.g.
`ARFFFiles.jl/src/ARFFFiles.jl`, `AnyMOD.jl/src/dataHandling/readIn.jl`,
`ArrayInterface.jl/src/static.jl`.

```julia
# ARFFFiles.jl/src/ARFFFiles.jl

parse_entry(::Type{T}, ::Any, ::Missing) where {T} = error("missing data found (expecting $T)")
parse_entry(::Type{T}, ::Any, ::Missing) where {T>:Missing} = missing

# ArrayInterface.jl/src/static.jl

function Base.promote_rule(::Type{T}, ::Type{<:StaticInt}) where {T>:Union{Missing,Nothing}}
    return promote_type(T, Int)
end
Base.promote_rule(::Type{T}, ::Type{<:StaticInt}) where {T>:Nothing} = promote_type(T, Int)
Base.promote_rule(::Type{T}, ::Type{<:StaticInt}) where {T>:Missing} = promote_type(T, Int)
```

Also used at run-time without multiple dispatch, but again,
for data reading, or type transformation
(essentially, relies on the invariance of parametric types)). E.g:

```julia
# Tables.jl/src/dicts.jl

function dictcolumntable(x)
  ...
    if !(eltype(col) >: Missing)
        new = allocatecolumn(Union{Missing, eltype(col)}, len)

# ScientificTypes.jl/src/scitype.jl

function arr_scitype(A::Arr{T,N}, C::Convention, S::Type;
                     tight::Bool=false) where {T,N}
    # no explicit scitype available
    S === Unknown && return Arr{scitype_union(A),N}
    # otherwise return `Arr{S,N}` or `Arr{Union{Missing,S},N}`
    if T >: Missing
        if tight
            has_missings = findfirst(ismissing, A) !== nothing
            !has_missings && return Arr{nonmissing(S),N}
        end
        return Arr{Union{S,Missing},N}
    end
    return Arr{S,N}
end

# MLJModels.jl/src/builtins/Transformers.jl seems to relies on sci types

    if elscitype(vnew) >: Missing
        w_tight = replace_missing(nonmissing(elscitype(vnew)), vnew, filler)

```

`CategoricalArrays.jl` use `Missing` for run-time checks a lot,
but also for dispatch:

```julia
            elseif S >: Missing || T >: Missing
                anymissing |= ismissing(eq)

function Base.Broadcast.broadcasted(::typeof(levelcode), A::CategoricalArray{T}) where {T}
    if T >: Missing
        Base.Broadcast.broadcasted(r -> r > 0 ? Signed(widen(r)) : missing, A.refs)
    else
        Base.Broadcast.broadcasted(r -> Signed(widen(r)), A.refs)
    end
end
```

### `$_` 8 and `$me` 1`

2 of those (and `$me`) are from `CanonicalTraits.jl` where it means
traits entailment (`X >: Y` means that `Y` is based on `X`)
rather than subtyping.

And the same exact function for extracting type variables is used in 

```julia
# CanonicalTraits.jl, GeneralizedGenerated.jl, ParameterisedModule.jl

extract_tvars(var :: Union{Symbol, Expr})::Symbol =
    @match var begin
        :($a <: $_) => a
        :($a >: $_) => a
        :($_ >: $a >: $_) => a
        :($_ <: $a <: $_) => a
        a::Symbol         => a
    end
```

`MLStyle.jl` also extracts type parameters:

```julia
@nospecialize
function take_type_parameters!(syms, ex)::Nothing
    @sswitch ex begin
    @case :($a >: $_) || :($a <: $_)
        @assert a isa Symbol
        push!(syms, a)
        return
    @case :($_ >: $b >: $_) || :($_ <: $b <: $_)
        @assert b isa Symbol    
        push!(syms, b)
        return
    @case ::Symbol
        push!(syms, ex)
        return
    @case _
        return
    end
end
```

### `Nothing` 7

Similar to `Missing`, also run-time checks. E.g. `ToStruct.jl`:

```julia
# ToStruct.jl/src/ToStruct.jl

function getdefault(T::Type, x::AbstractDict, k::Any)
    if T >: Nothing
        get(x, k, nothing)
    elseif T >: Missing
        get(x, k, missing)
    else
        x[k]
    end
end
```

### `$(tv.lb)` 2 and `$(to_expr(tr.lb))` 1

Both from `WhereTraits.jl`, related to parsing and reconstructing expressions?

```julia
# src/Utils/exprparsers.jl

# ExprParsers.to_expr(x::Union{DataType, UnionAll}) = Base.Meta.parse(repr(x))
function ExprParsers.to_expr(tv::TypeVar)
  if tv.lb === Union{} && tv.ub === Any
    tv.name
  elseif tv.lb === Union{}
    :($(tv.name) <: $(tv.ub))
  elseif tv.ub === Any
    :($(tv.name) >: $(tv.lb))
  else
    :($(tv.lb) <: $(tv.name) <: $(tv.ub))
  end
end

# src/Syntax/Parsing.jl
function parse_traitsfunction(env, func_parsed::EP.Function_Parsed, expr_original; on_traits_dropped = msg -> throw(ArgumentError(msg)))
...
  traits_matching_types = map(enumerate(extra_wheres)) do (i, expr)
    @match(expr) do f
      f(x::EP.Named{:arg, Symbol}) = :(Val{true})  # plain arguments are interpreted as bool
      f(x::EP.Named{:func, EP.Call_Parsed}) = (x.value.name == :!) ? :(Val{false}) : :(Val{true})  # plain calls are assumed to refer to boolean expressions
      f(x::EP.Named{<:Any, EP.TypeAnnotation_Parsed}) = to_expr(x.value.type)
      function f(x::EP.Named{<:Any, EP.TypeRange_Parsed})
        tr = x.value
        @assert !(tr.lb === Union{} && tr.ub == Any) "should have at least an upperbound or a lowerbound"
        if tr.lb === Union{}  # only upperbound
          :(Type{<:$(to_expr(tr.ub))})
        elseif tr.ub === Any  # only LowerBound
          :(Type{>:$(to_expr(tr.lb))})
        else  # both
          :(Type{T} where {$(to_expr(tr.lb)) <: T <: $(to_expr(tr.up))})
        end
      end
    end
  end
```

### `String` 4, `Int` 1

`AnyMOD.jl` and `DataConvenience.jl` run-time,
`ARFFFiles.jl` parsing.

### `$b` 2, `$a` 2

`JuliaVariables.jl` matching, looks somewhat similar to `$_` stuff.

### `T` 1 (interesting)

```julia
# ValueShapes.jl/src/array_shape.jl

function _bcasted_view_unchanged(data::AbstractArray{<:AbstractVector{T}}, shape::ArrayShape{U,1}) where {T<:Real,U>:T}
    _checkcompat_inner(shape, data)
    data
end
```

Looking at other uses of these types in the file, it seems that they want  T <: Real and T <: U. Function _checkcompat_inner looks only at the dimensions of shape and data.

### `$lb` 2 and `$(name_of_type(x.lb))` 2

Parsing again

```julia
# ExprParsers.jl/src/expr_parsers_with_parsed.jl

to_expr(parsed::TypeRange_Parsed) = _to_expr_TypeRange(parsed.lb, parsed.name, parsed.ub)
_to_expr_TypeRange(::Base.Type{Union{}}, name, ::Base.Type{Any}) = name
_to_expr_TypeRange(lb, name, ::Base.Type{Any}) = :($name >: $lb)
_to_expr_TypeRange(::Base.Type{Union{}}, name, ub) = :($name <: $ub)
_to_expr_TypeRange(lb, name, ub) = :($lb <: $name <: $ub)

# ExprTools.jl/src/method.jl
function where_constraint(x::TypeVar)
    if x.lb === Union{} && x.ub === Any
        return x.name
    elseif x.lb === Union{}
        return :($(x.name) <: $(name_of_type(x.ub)))
    elseif x.ub === Any
        return :($(x.name) >: $(name_of_type(x.lb)))
    else
        return :($(name_of_type(x.lb)) <: $(x.name) <: $(name_of_type(x.ub)))
    end
end
```

### `CheckedAxisLengths` 2, `CheckedOffsets` 1, `CheckedUniqueKeys` 1

`AxisIndices.jl` seems to be using lower bounds as flags that
something has been checked.
Instead of keeping a run-time value with booleans, they rely on types.

```julia
# AxisIndices.jl/src/errors.jl 

struct AxisArrayChecks{T}
    AxisArrayChecks{T}() where {T} = new{T}()
    AxisArrayChecks() = AxisArrayChecks{Union{}}()
end

struct CheckedAxisLengths end
checked_axis_lengths(::AxisArrayChecks{T}) where {T} = AxisArrayChecks{Union{T,CheckedAxisLengths}}()
check_axis_length(ks, inds, ::AxisArrayChecks{T}) where {T >: CheckedAxisLengths} = nothing
function check_axis_length(ks, inds, ::AxisArrayChecks{T}) where {T}
    if length(ks) != length(inds)
        throw(DimensionMismatch(
            "keys and indices must have same length, got length(keys) = $(length(ks))" *
            " and length(indices) = $(length(inds)).")
        )
    end
    return nothing
end

# AxisIndices.jl/src/axis_array.jl 

function compose_axis(ks, inds, checks)
    check_axis_length(ks, inds, checks)
    return _compose_axis(ks, inds, checked_axis_lengths(checks))
end

```

### `ExponentialKernel{T}, *Kernel{T}` 1 each

All come from the package `MLKernels.jl` which is deprecated.
All usages are similar to:

```julia
function convert(
        ::Type{K},
        κ::RationalQuadraticKernel
    ) where {K>:RationalQuadraticKernel{T}} where T
    return RationalQuadraticKernel{T}(κ.α, κ.β)
end
```

and `RationalQuadraticKernel{T}` is a concrete struct.

### `IsMeasurable` and similar 1 each

These are traits from `MeasureTheory.jl/src/traits.jl`,
not lower bounds.

```julia
@trait IsMeasure{M, X} >: HasDensity{M, X} where {X = eltype(M)} begin
    logdensity :: [M, X] => Real
end

@trait IsMeasure{M,X} >: IsMeasurable{M,S,X} where {X = eltype(S)} begin
    measure :: [M, S] => Real
end

@trait IsMeasure{M,X} >: HasRand{M,X} where {X = eltype(M)} begin
    rand :: [M] => eltype(M)
end
```

### `Tuple` 1

```julia
# HomotopyContinuation.jl/src/model_kit/instructions.jl

const InstructionArg = Union{Nothing,Number,Symbol,InstructionRef}

struct Instruction
    op::InstructionOp
    args::Tuple{InstructionArg,InstructionArg,InstructionArg}
end

Instruction(op::InstructionOp, a::T) where {T>:Tuple} =
    Instruction(op, (a, nothing, nothing))
Instruction(op, a, b) = Instruction(op, (a, b, nothing))
Instruction(op, a, b, c) = Instruction(op, (a, b, c))
```

I don't really understand this use of `>:`.

### `Any` 1

```julia
# DataValues.jl/src/array/constructors.jl
function Base.convert(::Type{DataValueArray{T,N}}, A::AbstractArray{S,N}) where {S >: Any,T,N}
    new_array = DataValueArray{T,N}(Array{T}(undef, size(A)), Array{Bool}(undef, size(A)))
    for i in eachindex(A)
        new_array[i] = A[i]
    end
    return new_array
end
```

## Only run-time checks from the raw data

```
valtype => 2                        (Stipple.jl)
Runtime => 2                        (Salsa.jl)
typeof(payload["newval"]) => 1      (Stipple.jl)
typeof(payload["oldval"]) => 1      (Stipple.jl)
OrderedFactor{2} => 1               (MLJBase.jl)
OrderedFactor{nc} => 1              (MLJBase.jl)
typeof(lattice) => 1                (QuantumLattices.jl)
```

## Only matching of expressions from the raw data

```
$_ => 8
$b => 2
$a => 2
(name_of_type(x.lb)) => 2
$lb => 2
$(tv.lb) => 2
$(to_expr(tr.lb)) => 1
$me => 1
```

## Raw data

```
Interesting packages: 50/4838
Lower bounds: 182
Unique lower bounds: 43
Missing  => 116
$_       => 8
Nothing  => 7
String   => 4
$b       => 2
$lb      => 2
Runtime  => 2
$a       => 2
$(name_of_type(x.lb)) => 2
$(tv.lb) => 2
valtype  => 2
CheckedAxisLengths => 2
CheckedUniqueKeys => 1
CheckedOffsets => 1
Union{Missing, Nothing} => 1
IsMeasurable{M, S, X} where (X = eltype(S)) => 1
HasRand{M, X} where (X = eltype(M)) => 1
HasDensity{M, X} where (X = eltype(M)) => 1
ExponentiatedKernel{T} => 1
GammaExponentialKernel{T} => 1
PowerKernel{T} => 1
ExponentialKernel{T} => 1
MaternKernel{T} => 1
SquaredExponentialKernel{T} => 1
SigmoidKernel{T} => 1
PolynomialKernel{T} => 1
RationalQuadraticKernel{T} => 1
LogKernel{T} => 1
GammaRationalQuadraticKernel{T} => 1
T        => 1
Tuple    => 1
Any      => 1
Float64  => 1
DateTime => 1
Int      => 1
$(to_expr(tr.lb)) => 1
$me      => 1
OrderedFactor{2} => 1
CategoricalValue{String, Int32} => 1
typeof(payload["oldval"]) => 1
typeof(payload["newval"]) => 1
OrderedFactor{nc} => 1
typeof(lattice) => 1
```