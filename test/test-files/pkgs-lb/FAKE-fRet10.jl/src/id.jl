
id(x::T) where T>:Any = x

id(x::T) where T>:Int = -x

println(id(5))
println(id(3.14))
