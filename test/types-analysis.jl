#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: getArgTypeAnn, getMethodTupleType

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fdefNoArg = :(
    fdefNoArg() = 0
)

dfedNoArgRet = :(
    dfedNoArgRet() :: Int = 0
)

fdefArgs = :(
    function fdefArgs(x, y::Vector{Bool}, z::Int = 0)
        "blah"
    end
)

fdefWhereTriv = :(
    fdefWhereTriv(x::T) where T = 0
)

fdefWhereRetSimp = :(
    (fdefWhereRetSimp(x::Dict{T, S}, y) :: Vector{T}) where {T, S} = T[]
)

fdefWhereRet = :( 
    function fdefWhereRet(
        a, b=0, c::Int=0, x::T, y::S, z::Vector{T}
    ) :: String where T<:S where S>:AbstractArray
      c+x
      "a"
    end
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "types-analysis :: get arg type annotation" begin
    # leading `;` tricks Julia into parsing `(...)` as argument list
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

#@testset "types-analysis :: get arg type annotation"
@testset "types-analysis :: get method tuple type  " begin
    splitDefs = Dict(map(
        fdef -> (namify(fdef) => splitdef(fdef)),
        [
            fdefNoArg,
            fdefArgs,
            fdefWhereTriv,
            fdefWhereRetSimp,
            fdefWhereRet
        ])...)
    # resulting tuple types
    tts = Dict(
        [f => getMethodTupleType(sd) for (f, sd) in splitDefs]...
    )

    @test tts[:fdefNoArg] == :( Tuple{} )
    @test tts[:fdefArgs]  == :( Tuple{Any, Vector{Bool}, Int} )
    @test tts[:fdefWhereTriv]    == :( Tuple{T} where T )
    @test tts[:fdefWhereRetSimp] == :( Tuple{Dict{T, S}, Any} where S where T )
    @test tts[:fdefWhereRet]     == 
        :( Tuple{Any, Any, Int, T, S, Vector{T}} where T<:S where S>:AbstractArray )
end

