#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: TypesAnlsBadMethodParamAST

using Main.JuliaSub: TypeDeclInfo, TypeDeclInfoList
using Main.JuliaSub: tdabst, tdprim, tdstrc, tdmtbl
using Main.JuliaSub: collectTypeDeclarations
#using Main.JuliaSub: parseAndCollectTypeAnnotations

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tdSingleStruct = :(
    struct Bar{X}
        x :: Int
    end
)

tdAllDecls = :(module M
    abstract type Zoo{X, Y} end

    struct Foo{T<:Ref{T} where T} <: Zoo{T,T}
        x :: T
        vs : Vector{T}
    end

    primitive type MyBits 64 end

    primitive type MyBitsVec <: AbstractVector{Bool} 64 end

    abstract type Bar{T<:Number} <: Number end

    struct Baz <: Bar{Int} end

    mutable struct MBar{X, Y<:Vector{X}} <: Bar{X} end

    mutable struct MyRef{T} <: Any
        val :: T
    end
end)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Extracting type declarations
#--------------------------------------------------

@testset "typedecls-analysis :: collect tydecls in expr " begin
    @test collectTypeDeclarations(:(x)) == nil()
    @test collectTypeDeclarations(:(module M end)) == nil()

    @test collectTypeDeclarations(tdSingleStruct) == list(
        TypeDeclInfo(:Bar, tdstrc, :( Bar{X} ), :Any)
    )

    @test collectTypeDeclarations(tdAllDecls) == reverse(list(
        TypeDeclInfo(:Zoo, tdabst, :( Zoo{X,Y} ), :Any),
        TypeDeclInfo(:Foo, tdstrc, :( Foo{T<:Ref{T} where T} ), :( Zoo{T,T} )),
        TypeDeclInfo(:MyBits, tdprim, :( MyBits ), :Any),
        TypeDeclInfo(:MyBitsVec, tdprim, :( MyBitsVec ), :( AbstractVector{Bool} )),
        TypeDeclInfo(:Bar, tdabst, :( Bar{T<:Number} ), :Number),
        TypeDeclInfo(:Baz, tdstrc, :Baz, :( Bar{Int} )),
        TypeDeclInfo(:MBar, tdmtbl, :( MBar{X, Y<:Vector{X}} ), :( Bar{X} )),
        TypeDeclInfo(:MyRef, tdmtbl, :( MyRef{T} ), :Any)
    ))
end