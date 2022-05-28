f(x::T, y::S) where {T>:Nothing, Int<:S<:Number} where Q>:Bool = 10

f(xs::Vect{>:String}, ys::Vector{>:T}) where T<:Number = xs
