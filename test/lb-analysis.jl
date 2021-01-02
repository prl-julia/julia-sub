#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: countTextualConstr
using Main.JuliaSub: subtc, suptc
using Main.JuliaSub: extractLowerBound, extractLowerBounds

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "lb-analysis :: sub/sup symbols" begin
    @test countTextualConstr(subtc, "")  == 0
    @test countTextualConstr(subtc, ":") == 0
    @test countTextualConstr(subtc, "<") == 0
    @test countTextualConstr(subtc, ">:")  == 0
    @test countTextualConstr(suptc, "  ab ") == 0
    @test countTextualConstr(suptc, "> :") == 0
    @test countTextualConstr(suptc, "<:")  == 0

    @test countTextualConstr(subtc, "<:")   == 1
    @test countTextualConstr(subtc, "<:<")  == 1
    @test countTextualConstr(suptc, ">:")   == 1
    @test countTextualConstr(suptc, " >::") == 1

    @test countTextualConstr(subtc, "where T <: Int") == 1
    @test countTextualConstr(subtc, "where Int<:T<:Number") == 2
    @test countTextualConstr(suptc, "where T >:   Int ") == 1
end

@testset "lb-analysis :: capture direct lower bound" begin
    @test extractLowerBound(:(T <: Number)) == nothing
    @test extractLowerBound(:(Number>:T>:Int)) == nothing

    @test extractLowerBound(:(T>:Int)) == :Int
    @test extractLowerBound(:( T >: Nothing )) == :Nothing
    @test extractLowerBound(:(Int <: T <: Bool)) == :Int
end

@testset "lb-analysis :: capture lower bounds" begin
    @test extractLowerBounds(:(f(x::T) where T = 0)) ==
        Multiset()
    @test extractLowerBounds(:(f(x::T) where T>:Int)) ==
        Multiset(:Int)
    @test extractLowerBounds(:(f(x::T) where {T>:Int, Nothing<:S<:Number} = 0)) ==
        Multiset(:Int, :Nothing)
    @test extractLowerBounds(:(f(x::T) where Int<:T where S<:Number = 0)) ==
        Multiset()
    @test extractLowerBounds(:(f(x::T) where T>:Int where S>:Int = 0)) ==
        Multiset(:Int, :Int)
    @test extractLowerBounds(:(f(x::T) where Int<:T<:S where S<:Number = 0)) ==
        Multiset(:Int)
    @test extractLowerBounds(:(f(x::T) where Int<:T<:S where S<:Number where U>:Bool = 0)) ==
        Multiset(:Int, :Bool)
    @test extractLowerBounds(:(f(x::T) where Int<:T<:S where {S<:Number, Int<:Q<:Nothing} where U>:Bool = 0)) ==
        Multiset(:Int, :Int, :Bool)
    @test extractLowerBounds(quote 
            f(x) = 5
            f(x, y::T) where T>:S where S = x
            const X = 7
            g(x::T) where {Int<:T<:Number, S<:Bool} = x
        end) ==
        Multiset(:Int, :S)
end