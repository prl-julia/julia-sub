#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: TypesAnlsBadMethodParamAST

using Main.JuliaSub: TypeAnnInfo, mtsig, retty, tyassorann, NOTAFUNSIG
using Main.JuliaSub: getArgTypeAnn, getMethodTupleType
using Main.JuliaSub: collectFunDefTypeSignature, collectTypeAnnotations

using Main.JuliaSub: TyVarSummary, TypeTyVarsSummary
using Main.JuliaSub: DEFAULT_LB, DEFAULT_UB, tcsempty, ANONYMOUS_TY_VAR
using Main.JuliaSub: TTok, TTlb, TTub, TypeTransInfo, transformShortHand
using Main.JuliaSub: TCTuple, TCInvar, TCUnion, TCWhere, TCLoBnd, TCUpBnd, TCVar, TCLBVar1, TCUBVar1, TCCall, TCMCall
using Main.JuliaSub: collectTyVarsSummary
using Main.JuliaSub: tyVarRestrictedScopePreserved, tyVarOccursAsImpredicativeUsedSiteVariance
using Main.JuliaSub: tyVarOccursAsUsedSiteVariance, tyVarUsedOnce, tyVarIsNotInLowerBound, existIsDeclaredInInv
using Main.JuliaSub: tyVarBoundsTrivConsistent

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fdefNoArg = :(
    fdefNoArg() = 0
)

dfedNoArgRet = :(
    dfedNoArgRet() :: Int = 0
)

fdefArgs = :(
    function fdefArgs(x, y::Vector{Bool}, z::Int = 0)
        baz :: Vector{<:Int}
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

fdefNoArgName = :(
    fdefNoArgName(::Int) = 0
)

fdefQualName = :(
    Base.fdefQualName(x::Int) :: Int = 0
)

fdefsSimpleX2 = :(begin
    $fdefNoArg

    $fdefWhereTriv
end)

fdefsSimpleNested = :(module X
    foo(x::Int) = 0

    struct Bar end

    struct Zoo
        x :: Bar
    end

    function baz(xs::Vector{T}, y::T) where T
        bar() = Bar()
        "abc" :: String
    end

    println()
end)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Extracting type annotations
#--------------------------------------------------

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
            fdefWhereRet,
            fdefNoArgName,
            fdefQualName
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
    @test tts[:fdefNoArgName] == :( Tuple{Int} )
end

@testset "types-analysis :: collect ty sig in mtdef     " begin
    tyAnns = nil(TypeAnnInfo)
    e = :()

    (e, tyAnns) = collectFunDefTypeSignature(fdefNoArg, tyAnns)
    @test tyAnns ==
        list(TypeAnnInfo(:fdefNoArg, mtsig, :( Tuple{} )))
    
    (e, tyAnns) = collectFunDefTypeSignature(fdefWhereTriv, tyAnns)
    @test tyAnns ==
        list(
            TypeAnnInfo(:fdefWhereTriv, mtsig, :( Tuple{T} where T )),
            TypeAnnInfo(:fdefNoArg, mtsig, :( Tuple{} ))
        )

    @test collectFunDefTypeSignature(fdefWhereRetSimp, nil(TypeAnnInfo))[2] ==
        list(
            TypeAnnInfo(
                :fdefWhereRetSimp, retty,
                :( Vector{T} ) 
            ),
            TypeAnnInfo(
                :fdefWhereRetSimp, mtsig, 
                :( Tuple{Dict{T, S}, Any} where S where T )
            )
        )
    
    @test collectFunDefTypeSignature(fdefQualName, nil(TypeAnnInfo))[2] == 
        list(
            TypeAnnInfo(:(Base.fdefQualName), retty, :Int),
            TypeAnnInfo(:(Base.fdefQualName), mtsig, :( Tuple{Int} ))
        )
end

@testset "types-analysis :: collect all ty-anns in expr " begin
    @test collectTypeAnnotations(:(x)) == nil()

    @test collectTypeAnnotations(fdefsSimpleX2) == list(
        TypeAnnInfo(:fdefWhereTriv, mtsig, :( Tuple{T} where T )),
        TypeAnnInfo(:fdefNoArg, mtsig, :( Tuple{} ))
    )

    @test collectTypeAnnotations(fdefsSimpleNested) == list(
        TypeAnnInfo(NOTAFUNSIG, tyassorann, :String),
        TypeAnnInfo(:bar, mtsig, :( Tuple{} )),
        TypeAnnInfo(:baz, mtsig, :( Tuple{Vector{T}, T} where T )),
        TypeAnnInfo(NOTAFUNSIG, tyassorann, :Bar),
        TypeAnnInfo(:foo, mtsig, :( Tuple{Int} ))
    )

    @test collectTypeAnnotations(fdefArgs) == list(
        TypeAnnInfo(NOTAFUNSIG, tyassorann, :( Vector{<:Int} )),
        TypeAnnInfo(:fdefArgs, mtsig, :( Tuple{Any, Vector{Bool}, Int} ))
    )
end

#--------------------------------------------------
# Analyzing type annotations
#--------------------------------------------------

@testset "types-analysis :: removing shorthand bounds   " begin
    @test transformShortHand(:(Int)) == TypeTransInfo(:(Int))

    ubTr = transformShortHand(:(<:Number)) 
    @test ubTr.kind == TTub
    @test ubTr.expr isa Symbol
    @test ubTr.bound == :Number

    tupleRefTr = transformShortHand(:(Tuple{Ref{>:T}} where T))
    @test tupleRefTr.kind == TTok
    @test tupleRefTr.expr isa Expr
    tupleRefInnerRef = tupleRefTr.expr.args[1].args[2]
    @test tupleRefInnerRef isa Expr
    @test tupleRefInnerRef.head == :where
end

@testset "types-analysis :: collect type vars summary   " begin
    @test collectTyVarsSummary(:(Int)) == (TypeTyVarsSummary(), false)

    @test collectTyVarsSummary(:(T where T)) ==
        ([TyVarSummary(:T, DEFAULT_LB, DEFAULT_UB, [tcsempty()], tcsempty())], false)

    @test collectTyVarsSummary(:(Tuple{T, Pair{T, S} where S>:T} where T<:Number)) == ([
            TyVarSummary(:S, :T, DEFAULT_UB, 
                [list(TCInvar)], list(TCTuple, TCWhere)),
            TyVarSummary(:T, DEFAULT_LB, :Number, 
                [
                    list(TCTuple),
                    list(TCLoBnd, TCTuple),
                    list(TCInvar, TCWhere, TCTuple)
                ],
                tcsempty()),
        ], false)

    @test collectTyVarsSummary(:(Pair{X, T} where X<:Number where Int<:T<:(Foo{Y} where Y>:Int))) == ([
        TyVarSummary(:Y, :Int, DEFAULT_UB, 
            [list(TCInvar)], list(TCUpBnd)),
        TyVarSummary(:X, DEFAULT_LB, :Number,
            [list(TCInvar)], list(TCWhere)),
        TyVarSummary(:T, :Int, :(Foo{Y} where Y>:Int), 
            [list(TCInvar, TCWhere)], tcsempty()),
    ], false)
end

@testset "types-analysis :: analysis of type vars usage " begin
    tvsInt = collectTyVarsSummary(:(Int))[1]
    @test tyVarUsedOnce(tvsInt)
    @test tyVarOccursAsUsedSiteVariance(tvsInt)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsInt)
    @test tyVarRestrictedScopePreserved(tvsInt)
    @test tyVarIsNotInLowerBound(tvsInt)
    @test !existIsDeclaredInInv(tvsInt)
    @test tyVarBoundsTrivConsistent(tvsInt)

    tvsVector = collectTyVarsSummary(:(Vector{T} where T))[1]
    @test tyVarUsedOnce(tvsVector)
    @test tyVarOccursAsUsedSiteVariance(tvsVector)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsVector)
    @test tyVarRestrictedScopePreserved(tvsVector)
    @test tyVarIsNotInLowerBound(tvsVector)
    @test !existIsDeclaredInInv(tvsVector)
    @test tyVarBoundsTrivConsistent(tvsVector)

    tvsPair = collectTyVarsSummary(:(Pair{T, T} where T))[1]
    @test !tyVarUsedOnce(tvsPair)
    @test !tyVarOccursAsUsedSiteVariance(tvsPair)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsPair)
    @test tyVarRestrictedScopePreserved(tvsPair)
    @test !existIsDeclaredInInv(tvsPair)
    @test tyVarBoundsTrivConsistent(tvsPair)

    tvsRefPair = collectTyVarsSummary(:(Ref{Pair{T, T} where T}))[1]
    @test !tyVarUsedOnce(tvsRefPair)
    @test !tyVarOccursAsUsedSiteVariance(tvsRefPair)
    @test !tyVarOccursAsImpredicativeUsedSiteVariance(tvsRefPair)
    @test tyVarRestrictedScopePreserved(tvsRefPair)
    @test existIsDeclaredInInv(tvsRefPair)

    tvsRefTuplePair = collectTyVarsSummary(:(Ref{Tuple{Pair{T, T} where T}}))[1]
    @test !tyVarUsedOnce(tvsRefTuplePair)
    @test !tyVarOccursAsUsedSiteVariance(tvsRefTuplePair)
    @test !tyVarOccursAsImpredicativeUsedSiteVariance(tvsRefTuplePair)
    @test tyVarRestrictedScopePreserved(tvsRefTuplePair)
    @test existIsDeclaredInInv(tvsRefTuplePair)

    tvsTuple = collectTyVarsSummary(:(Tuple{T, Tuple{T, Int}} where T))[1]
    @test !tyVarUsedOnce(tvsTuple)
    @test !tyVarOccursAsUsedSiteVariance(tvsTuple) # diagonal rule
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTuple)
    @test tyVarRestrictedScopePreserved(tvsTuple)
    @test !existIsDeclaredInInv(tvsTuple)

    tvsTupleRef = collectTyVarsSummary(:(Tuple{Ref{T}} where T))[1]
    @test tyVarUsedOnce(tvsTupleRef)
    @test tyVarOccursAsUsedSiteVariance(tvsTupleRef)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTupleRef)
    @test tyVarRestrictedScopePreserved(tvsTupleRef)
    @test !existIsDeclaredInInv(tvsTupleRef)

    tvsTupleTRef = collectTyVarsSummary(:(Tuple{T, Ref{T}} where T))[1]
    @test !tyVarUsedOnce(tvsTupleTRef)
    @test !tyVarOccursAsUsedSiteVariance(tvsTupleTRef)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTupleTRef)
    @test tyVarRestrictedScopePreserved(tvsTupleTRef)
    @test !existIsDeclaredInInv(tvsTupleTRef)

    tvsTupleRefTuple = collectTyVarsSummary(:(Tuple{Ref{Tuple{T}}} where T))[1]
    @test tyVarUsedOnce(tvsTupleRefTuple)
    @test !tyVarOccursAsUsedSiteVariance(tvsTupleRefTuple)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTupleRefTuple)
    @test tyVarRestrictedScopePreserved(tvsTupleRefTuple)
    @test !existIsDeclaredInInv(tvsTupleRefTuple)

    tvsRefUnion = collectTyVarsSummary(:(Vector{Union{T, Int}} where T))[1]
    @test tyVarUsedOnce(tvsRefUnion)
    @test !tyVarOccursAsUsedSiteVariance(tvsRefUnion)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsRefUnion)
    @test !tyVarRestrictedScopePreserved(tvsRefUnion)
    @test !existIsDeclaredInInv(tvsRefUnion)

    tvsRefWhereRef = collectTyVarsSummary(:(Ref{Ref{T} where T} where T))[1]
    @test !tyVarUsedOnce(tvsRefWhereRef)
    @test tyVarUsedOnce(tvsRefWhereRef[1]) # inner T
    @test !tyVarUsedOnce(tvsRefWhereRef[2]) # outer T
    @test tyVarOccursAsUsedSiteVariance(tvsRefWhereRef)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsRefWhereRef)
    @test tyVarRestrictedScopePreserved(tvsRefWhereRef)
    @test existIsDeclaredInInv(tvsRefWhereRef)

    tvsRefWherePair = collectTyVarsSummary(:(Ref{Pair{T, S} where S} where T))[1]
    @test tyVarUsedOnce(tvsRefWherePair)
    @test !tyVarOccursAsUsedSiteVariance(tvsRefWherePair)
    @test tyVarOccursAsUsedSiteVariance(tvsRefWherePair[1]) # S
    @test !tyVarOccursAsUsedSiteVariance(tvsRefWherePair[2]) # T
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsRefWherePair)
    @test !tyVarRestrictedScopePreserved(tvsRefWherePair)
    @test tyVarRestrictedScopePreserved(tvsRefWherePair[1]) # S
    @test !tyVarRestrictedScopePreserved(tvsRefWherePair[2]) # T
    @test existIsDeclaredInInv(tvsRefWherePair)

    tvsPairWherePair = collectTyVarsSummary(:(Pair{S, Pair{Int, T} where T<:S} where S))[1]
    @test !tyVarUsedOnce(tvsPairWherePair)
    @test tyVarUsedOnce(tvsPairWherePair[1]) # T
    @test !tyVarUsedOnce(tvsPairWherePair[2]) # S
    @test !tyVarOccursAsUsedSiteVariance(tvsPairWherePair)
    @test tyVarOccursAsUsedSiteVariance(tvsPairWherePair[1]) # T
    @test !tyVarOccursAsUsedSiteVariance(tvsPairWherePair[2]) # S
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsPairWherePair)
    @test !tyVarRestrictedScopePreserved(tvsPairWherePair)
    @test tyVarRestrictedScopePreserved(tvsPairWherePair[1]) # T
    @test !tyVarRestrictedScopePreserved(tvsPairWherePair[2]) # S
    @test existIsDeclaredInInv(tvsPairWherePair)
    @test tyVarBoundsTrivConsistent(tvsPairWherePair)

    tvsTupleWherePair = collectTyVarsSummary(:(Tuple{S, Pair{T, S} where T<:S} where S))[1]
    @test !tyVarUsedOnce(tvsTupleWherePair)
    @test !tyVarOccursAsUsedSiteVariance(tvsTupleWherePair)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTupleWherePair)
    @test tyVarRestrictedScopePreserved(tvsTupleWherePair)
    @test tyVarIsNotInLowerBound(tvsTupleWherePair)
    @test !existIsDeclaredInInv(tvsTupleWherePair)

    tvsPairInLb = collectTyVarsSummary(:(Tuple{T} where T>:(Pair{S,S} where S)))[1]
    @test !tyVarUsedOnce(tvsPairInLb)
    @test tyVarUsedOnce(tvsPairInLb[2]) # T
    @test !tyVarOccursAsUsedSiteVariance(tvsPairInLb)
    @test tyVarOccursAsUsedSiteVariance(tvsPairInLb[2]) # T
    @test !tyVarOccursAsImpredicativeUsedSiteVariance(tvsPairInLb)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsPairInLb[2]) # T
    @test tyVarRestrictedScopePreserved(tvsPairInLb)
    @test tyVarIsNotInLowerBound(tvsPairInLb)
    @test !existIsDeclaredInInv(tvsPairInLb)
    @test tyVarBoundsTrivConsistent(tvsPairInLb)

    tvsTupleRefLB = collectTyVarsSummary(:(Tuple{Ref{T} where T>:S} where S))[1]
    @test tyVarUsedOnce(tvsTupleRefLB)
    @test tyVarOccursAsUsedSiteVariance(tvsTupleRefLB)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTupleRefLB)
    @test tyVarRestrictedScopePreserved(tvsTupleRefLB)
    @test !tyVarIsNotInLowerBound(tvsTupleRefLB)
    @test !existIsDeclaredInInv(tvsTupleRefLB)

    tvsVectorVectorUnionTInt = collectTyVarsSummary(:(Vector{Vector{Union{T, Int}} where T}))[1]
    @test tyVarUsedOnce(tvsVectorVectorUnionTInt)
    @test !tyVarOccursAsUsedSiteVariance(tvsVectorVectorUnionTInt)
    @test !tyVarOccursAsImpredicativeUsedSiteVariance(tvsVectorVectorUnionTInt)
    @test !tyVarRestrictedScopePreserved(tvsVectorVectorUnionTInt)
    @test tyVarIsNotInLowerBound(tvsVectorVectorUnionTInt)
    @test existIsDeclaredInInv(tvsVectorVectorUnionTInt)

    tvsVectorRefTupleT = collectTyVarsSummary(:(Vector{Ref{Tuple{T}} where T}))[1]
    @test tyVarUsedOnce(tvsVectorRefTupleT)
    @test !tyVarOccursAsUsedSiteVariance(tvsVectorRefTupleT)
    @test !tyVarOccursAsImpredicativeUsedSiteVariance(tvsVectorRefTupleT)
    @test tyVarRestrictedScopePreserved(tvsVectorRefTupleT)
    @test tyVarIsNotInLowerBound(tvsVectorRefTupleT)
    @test existIsDeclaredInInv(tvsVectorRefTupleT)

    tvsRefUBRef = collectTyVarsSummary(:(Ref{T} where T<:(Ref{S} where S)))[1]
    @test tyVarUsedOnce(tvsRefUBRef)
    @test tyVarOccursAsUsedSiteVariance(tvsRefUBRef)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsRefUBRef)
    @test tyVarRestrictedScopePreserved(tvsRefUBRef)
    @test tyVarIsNotInLowerBound(tvsRefUBRef)
    @test !existIsDeclaredInInv(tvsRefUBRef)

    tvsTupleUBRefRef = collectTyVarsSummary(
        transformShortHand(:(Tuple{T} where T<:Ref{Ref{<:Any}})).expr
    )[1]
    @test tyVarUsedOnce(tvsTupleUBRefRef)
    @test tyVarOccursAsUsedSiteVariance(tvsTupleUBRefRef)
    @test tyVarOccursAsImpredicativeUsedSiteVariance(tvsTupleUBRefRef)
    @test tyVarRestrictedScopePreserved(tvsTupleUBRefRef)
    @test tyVarIsNotInLowerBound(tvsTupleUBRefRef)
    @test existIsDeclaredInInv(tvsTupleUBRefRef)
    @test tyVarBoundsTrivConsistent(tvsTupleUBRefRef)

    tvsTrivLbUb1 = collectTyVarsSummary(:(Ref{T} where Union{}<:T<:Any))[1]
    @test tyVarBoundsTrivConsistent(tvsTrivLbUb1)
    tvsTrivLbUb2 = collectTyVarsSummary(:(Ref{T} where Int<:T<:Any))[1]
    @test tyVarBoundsTrivConsistent(tvsTrivLbUb2)
    tvsTrivLbUb3 = collectTyVarsSummary(:(Ref{T} where Union{}<:T<:Number))[1]
    @test tyVarBoundsTrivConsistent(tvsTrivLbUb3)
    tvsNonTrivLbUb = collectTyVarsSummary(:(Ref{T} where Int<:T<:Vector{Int}))[1]
    @test !tyVarBoundsTrivConsistent(tvsNonTrivLbUb)
    tvsNonTrivLbUbInner = collectTyVarsSummary(:
        (Tuple{S, Ref{T} where Int<:T<:Number} where S)
    )[1]
    @test !tyVarBoundsTrivConsistent(tvsNonTrivLbUbInner)
end
