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