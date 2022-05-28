module Multisets

import Base: show, length, getindex, collect, union, intersect, isempty, first
import Base: push!, setindex!, delete!, hash, eltype
import Base: (*), (+), (-)
import Base: issubset, Set, (==)


export Multiset, set_short_show, set_julia_show, set_braces_show, set_key_value_show

"""
A `Multiset` is an unordered collection of things with repetition permitted.
A new `Multiset` container is created with `Multiset{T}()` where `T` is the
type of the objects held in the multiset. If `T` is omitted, it defaults
to `Any`.
A `Multiset` can be created from a collection `list` (such as a `Vector` or
`Set`) with `Multiset(list)`. If an element is repeated in `list` it has
the appropriate multiplicity.
"""
struct Multiset{T} <: AbstractSet{T}
    data::Dict{T,Int}
    function Multiset{T}() where {T}
        d = Dict{T,Int}()
        new(d)
    end
end
Multiset() = Multiset{Any}()
Multiset(x...) = Multiset(collect(x))

function Base.copy(M::Multiset{T}) where {T}
    newMultiset = Multiset{T}()
    for (key, value) in pairs(M)
        newMultiset[key] = value
    end
    return newMultiset
end

function Base.empty!(M::Multiset{T}) where {T}
    for (key, value) in pairs(M)
        M[key] = 0
    end
    clean!(M)
    return M
end

eltype(M::Multiset{T}) where {T} = T

function Multiset(list::AbstractArray{T,d}) where {T,d}
    M = Multiset{T}()
    for x in list
        push!(M, x)
    end
    return M
end

function Multiset(A::Base.AbstractSet{T}) where {T}
    M = Multiset{T}()
    for x in A
        push!(M, x)
    end
    return M
end

"""
`clean!(M)` removes elements of multiplicy 0 from the underlying data
structure supporting `M`.
"""
function clean!(M::Multiset)
    for x in keys(M.data)
        if M[x] == 0
            delete!(M.data, x)
        end
    end
    nothing
end


"""
For a `M[t]` where `M` is a `Multiset` returns the
multiplicity of `t` in `M`. A value of `0` means that
`t` is not a member of `M`.
"""
function getindex(M::Multiset{T}, x)::Int where {T}
    if haskey(M.data, x)
        return M.data[x]
    end
    return 0
end

"""
`push!(M,x,incr)` increases the multiplicity of `x` in `M`
by `incr` (which defaults to 1). `incr` can be negative, but
it is not possible to decrease the multiplicty below 0.
"""
function push!(M::Multiset{T}, x, incr::Int = 1) where {T}
    if haskey(M.data, x)
        M.data[x] += incr
    else
        M.data[x] = incr
    end
    if M.data[x] < 0
        M.data[x] = 0
    end
    return M
end

end #module
