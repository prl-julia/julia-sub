#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: TypesAnlsBadMethodParamAST

using Main.JuliaSub: TypeAnnInfo, mtsig, retty, tyass
using Main.JuliaSub: getArgTypeAnn, getMethodTupleType
using Main.JuliaSub: collectFunDefTypeAnnotations, collectTypeAnnotations
using Main.JuliaSub: parseAndCollectTypeAnnotations


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

fdefsSimpleX2 = :(begin
    $fdefNoArg

    $fdefWhereTriv
end)

fdefsSimpleNested = :(module X
    foo(x::Int) = 0

    struct Bar end

    function baz(xs::Vector{T}, y::T) where T
        bar() = Bar()
        "abc"
    end

    println()
end)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "types-analysis :: get argument type annotation" begin
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

    @test_throws TypesAnlsBadMethodParamAST getArgTypeAnn(:(T <: Number))
end

@testset "types-analysis :: get method type signature   " begin
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

# FIXME: collectFunDefTypeAnnotations currently extracts only method signature
@testset "types-analysis :: collect all ty-anns in mtdef" begin
    tyAnns = nil(TypeAnnInfo)

    tyAnns = collectFunDefTypeAnnotations(fdefNoArg, tyAnns)
    @test tyAnns ==
        list(TypeAnnInfo(:fdefNoArg, mtsig, :( Tuple{} )))
    
    tyAnns = collectFunDefTypeAnnotations(fdefWhereTriv, tyAnns)
    @test tyAnns ==
        list(
            TypeAnnInfo(:fdefWhereTriv, mtsig, :( Tuple{T} where T )),
            TypeAnnInfo(:fdefNoArg, mtsig, :( Tuple{} ))
        )

    @test collectFunDefTypeAnnotations(fdefWhereRetSimp, nil(TypeAnnInfo)) ==
        list(TypeAnnInfo(
            :fdefWhereRetSimp, mtsig, 
            :( Tuple{Dict{T, S}, Any} where S where T )))
    
    @test collectFunDefTypeAnnotations(:(f()), nil(TypeAnnInfo)) == nil()
end

# FIXME: collectFunDefTypeAnnotations currently extracts only method signature
@testset "types-analysis :: collect all ty-anns in expr " begin
    @test collectTypeAnnotations(:(x)) == nil()

    @test collectTypeAnnotations(fdefsSimpleX2) == list(
        TypeAnnInfo(:fdefWhereTriv, mtsig, :( Tuple{T} where T )),
        TypeAnnInfo(:fdefNoArg, mtsig, :( Tuple{} ))
    )

    @test collectTypeAnnotations(fdefsSimpleNested) == list(
        TypeAnnInfo(:bar, mtsig, :( Tuple{} )),
        TypeAnnInfo(:baz, mtsig, :( Tuple{Vector{T}, T} where T )),
        TypeAnnInfo(:foo, mtsig, :( Tuple{Int} ))
    )
end

# FIXME: collectFunDefTypeAnnotations currently extracts only method signature
@testset "types-analysis :: collect all ty-anns in file " begin
    @test parseAndCollectTypeAnnotations(testFilePath("empty.jl")) == nil()

    @test parseAndCollectTypeAnnotations(
            testFilePath("Multisets-cut.jl")
        ) == list(
            TypeAnnInfo(:push!, mtsig, :( Tuple{Multiset{T}, Any, Int} where T )),
            TypeAnnInfo(:getindex, mtsig, :( Tuple{Multiset{T}, Any} where T )),
            TypeAnnInfo(:clean!, mtsig, :( Tuple{Multiset} )),
            TypeAnnInfo(:Multiset, mtsig, :( Tuple{Base.AbstractSet{T}} where T )),
            TypeAnnInfo(:Multiset, mtsig, :(( Tuple{AbstractArray{T, d}} where d) where T )), 
            TypeAnnInfo(:eltype, mtsig, :( Tuple{Multiset{T}} where T )),
            TypeAnnInfo(:(Base.empty!), mtsig, :( Tuple{Multiset{T}} where T )),
            TypeAnnInfo(:(Base.copy), mtsig, :( Tuple{Multiset{T}} where T )),
            TypeAnnInfo(:Multiset, mtsig, :( Tuple{Vararg{Any}} )),
            TypeAnnInfo(:Multiset, mtsig, :( Tuple{} )),
            TypeAnnInfo(:Multiset, mtsig, :( Tuple{} where T ))
        )
end