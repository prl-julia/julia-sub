#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: TypesAnlsBadMethodParamAST

using Main.JuliaSub: TypeDeclInfo, TypeDeclInfoList
using Main.JuliaSub: tdabst, tdprim, tdstrc, tdmtbl
using Main.JuliaSub: collectTypeDeclarations

using Main.JuliaSub: extractVarName, splitTyDecl, wrapTyInWhere
using Main.JuliaSub: tyDeclAndSuper2FullTypes

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

#--------------------------------------------------
# Splitting type declaration
#--------------------------------------------------

@testset "typedecls-analysis :: extract var name        " begin
    @test splitTyDecl(:(Bar))    == (:Bar, [], [])
    @test splitTyDecl(:(Zoo{T})) == (:(Zoo{T}), [:T], [:T])
    @test splitTyDecl(:(Foo{Int<:X<:Number, Y<:Vector{X}})) == 
        (:(Foo{X, Y}), [:(Int<:X<:Number), :(Y<:Vector{X})], [:X, :Y])
end

@testset "typedecls-analysis :: split type decl         " begin
    @test extractVarName(:(Int<:X<:Number)) == :X
    @test extractVarName(:(T>:Vector))      == :T
    @test extractVarName(:(N<:Number))      == :N
    @test extractVarName(:(V))              == :V
end

#--------------------------------------------------
# Transforming type declaration
#--------------------------------------------------

@testset "typedecls-analysis :: wrap in where           " begin
    @test wrapTyInWhere(:Int, []) == :Int
    @test wrapTyInWhere(:(Ref{Foo}), []) == :(Ref{Foo})
    @test wrapTyInWhere(:(Ref{X}), [:X]) == :(Ref{X} where X)
    @test wrapTyInWhere(:(Ref{X}), [:(X>:Missing)]) == 
        :(Ref{X} where X>:Missing)
    @test wrapTyInWhere(:(Foo{X, Y}), [:X, :(Y<:Ref{X})]) == 
        :(Foo{X, Y} where Y<:Ref{X} where X)
    @test wrapTyInWhere(:(Baz{X, Vector{X}}), [:(Int<:X<:Number)]) == 
        :(Baz{X, Vector{X}} where Int<:X<:Number)
end

@testset "typedecls-analysis :: trnsfrm ty-decl & super " begin
    @test tyDeclAndSuper2FullTypes(:Bar, :Foo) == (:Bar, 0, :Foo)
    @test tyDeclAndSuper2FullTypes(:(Ref{X}), :AbsRef) == 
        (:(Ref{X} where X), 1, :(AbsRef where X))
    @test tyDeclAndSuper2FullTypes(:(Foo{T<:Number, S<:Vector{T}}), :(Bar{T, T})) == 
        (:(Foo{T, S} where S<:Vector{T} where T<:Number), 
         2,
         :(Bar{T, T} where S where T))
end

