#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: getArgTypeAnn

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fdef1 = :( 
    function foo(
        a, b=0, c::Int=0, x::T, y::S, z::Vector{T}
    ) where T<:S where S>:AbstractArray :: String
      c+x
      "a"
    end
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "types-analysis :: get argument type annotation" begin
    # tricking Julia into parsing as arguments
    paramsList = 
        :( (; x, y = 0, z :: Int, w :: Bool = false, v :: Vector{T} where T) )
    params = paramsList.args[1].args

    # x
    @test getArgTypeAnn(params[1]) == :Any
    # y = 0
    @test getArgTypeAnn(params[2]) == :Any
    # z :: Int
    @test getArgTypeAnn(params[3]) == :Int
    # w :: Bool = false
    @test getArgTypeAnn(params[4]) == :Bool
    # v :: Vector{T} where T
    @test getArgTypeAnn(params[5]) == :(Vector{T} where T)
end

