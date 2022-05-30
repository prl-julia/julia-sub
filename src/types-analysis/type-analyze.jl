#######################################################################
# Analyzing type annotations for their type variables usage
###############################
#
# TODO 
#
#######################################################################

const ANONYMOUS_TY_VAR = :ANON_TV

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analyzing type variable summaries for restrictions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


tyVarRestrictedScopePreserved(tytvs :: TypeTyVarsSummary) = 
    all(tyVarRestrictedScopePreserved, tytvs)

tyVarRestrictedScopePreserved(tvs :: TyVarSummary) = 
    all(tyVarRestrictedScopePreserved, map(reverse, tvs.occurrs))

tyVarRestrictedScopePreserved(
    constrStack :: Nil{TypeConstructor}; invarCrossed :: Bool = false
) = true
tyVarRestrictedScopePreserved(
    constrStack :: Cons{TypeConstructor}; invarCrossed :: Bool = false
) = begin
    (hd, tl) = (DataStructures.head(constrStack), DataStructures.tail(constrStack))
    if hd == TCInvar || hd == TCLoBnd || hd == TCLBVar1
        tyVarRestrictedScopePreserved(tl; invarCrossed = true)
    elseif hd == TCWhere || hd == TCLoBnd || hd == TCUpBnd || hd == TCUnion 
        invarCrossed ? false : tyVarRestrictedScopePreserved(tl)
    else 
        tyVarRestrictedScopePreserved(tl)
    end
end


tyVarOccursAsUsedSiteVariance(tytvs :: TypeTyVarsSummary) = 
    all(tyVarOccursAsUsedSiteVariance, tytvs)

"""
For wildcards-like restriction, type variable can be used only once
in an invariant or cotravariant position
"""
tyVarOccursAsUsedSiteVariance(tvs :: TyVarSummary) = begin
    covOccs = count(tyVarOccIsCovariant, map(reverse, tvs.occurrs))
    # either all occurrences are covariant, or there is only one
    # non-covariant occurrence
    covOccs == length(tvs.occurrs) || 
    length(tvs.occurrs) == 1 && tyVarNonCovOccIsImmediate(reverse(tvs.occurrs[1]))
end

tyVarOccIsCovariant(constrStack :: Nil{TypeConstructor}) = true
tyVarOccIsCovariant(constrStack :: Cons{TypeConstructor}) =
    DataStructures.head(constrStack) in [TCTuple, TCUnion, TCWhere, TCUpBnd, TCUBVar1] &&
    tyVarOccIsCovariant(DataStructures.tail(constrStack))

tyVarNonCovOccIsImmediate(constrStack :: Nil{TypeConstructor}) = true
tyVarNonCovOccIsImmediate(constrStack :: Cons{TypeConstructor}) = 
    DataStructures.head(constrStack) in [TCTuple, TCUnion, TCWhere, TCUpBnd, TCUBVar1] ||
    isempty(DataStructures.tail(constrStack))


"All vars used exactly once"
tyVarUsedOnce(tytvs :: TypeTyVarsSummary) = 
    all(tyVarUsedOnce, tytvs)

tyVarUsedOnce(tvs :: TyVarSummary) = length(tvs.occurrs) == 1

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Summarizing type variable usage
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

collectTyVarsSummary(ty :: JlASTTypeExpr) = 
    collectTyVarsSummary!(ty, envempty(), TypeTyVarsSummary())


"""
The second return value indicates if any potential problems were encountered

EFFECT: modifies `tvsumm`
"""
collectTyVarsSummary!(
    ty :: JlASTTypeExpr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = isprimitivetype(typeof(ty)) || ty isa String ?
    (tvsumm, false) :
    begin
        #@warn "Unsupported type annotation" ty
        #tvsumm
        @error "Unsupported type annotation" ty typeof(ty)
        throw(TypesAnlsUnsupportedTypeAnnotation(ty))
    end

"""
Symbol may represent a variable occurrence
"""
collectTyVarsSummary!(
    ty :: Symbol,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    tvInfo = envlookup(env, ty)
    tvInfo === nothing || # ty is a variable occurrence
        push!(tvInfo.occurrs, tvInfo.currPos)
    (tvsumm, false)
end

collectTyVarsSummary!(
    ty :: Expr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    if ty.head == :(.) # qualified name
        (tvsumm, false) # nothing to do, it's definitely not a variable occurrence
    elseif ty.head == :where
        # The process of extracting type annotations should produce where types
        # with single variables, i.e.
        # `t where X where Y`` instead of `t where {X, Y}`
        @assert length(ty.args) == 2 "Expected single variable in a where type"
        collectTyVarsSummaryWhere!(ty.args[1], ty.args[2], env, tvsumm)
    elseif ty.head == :curly
        @assert length(ty.args) >= 1 "Unsupported {} $ty"
        collectTyVarsSummaryCurly!(ty.args, env, tvsumm)
    elseif ty.head == :(<:) # Ref{<:ub}
        @assert length(ty.args) == 1 "Unsupported short-hand <:" ty
        envUB = envpushconstr(env, TCUpBnd)
        (_, problemEncountered) = collectTyVarsSummary!(ty.args[1], envUB, tvsumm)
        push!(tvsumm,
            TyVarSummary(ANONYMOUS_TY_VAR, DEFAULT_LB, ty.args[1], [list(TCUBVar1)]))
        (tvsumm, problemEncountered)
    elseif ty.head == :(>:) # Ref{>:lb}
        @assert length(ty.args) == 1 "Unsupported short-hand >: " ty
        envLB = envpushconstr(env, TCLoBnd)
        (_, problemEncountered) = collectTyVarsSummary!(ty.args[1], envLB, tvsumm)
        push!(tvsumm,
            TyVarSummary(ANONYMOUS_TY_VAR, ty.args[1], DEFAULT_UB, [list(TCLBVar1)]))
        (tvsumm, problemEncountered)
    elseif ty.head == :call
        envArg = envpushconstr(env, TCCall)
        problemEncountered = false
        for arg in ty.args
            (_, problem) = collectTyVarsSummary!(arg, envArg, tvsumm)
            problem && (problemEncountered = true)
        end
        (tvsumm, problemEncountered)
    elseif ty.head == :macrocall
        envArg = envpushconstr(env, TCMCall)
        problemEncountered = false
        for arg in ty.args
            (_, problem) = collectTyVarsSummary!(arg, envArg, tvsumm)
            problem && (problemEncountered = true)
        end
        (tvsumm, problemEncountered)
    elseif ty.head == :($)
        (tvsumm, true) # conservatively assuming that something may be in there
    elseif ty.head == :tuple
        (tvsumm, true) # conservatively assuming that something may be in there
    else
        #@warn "Unsupported Expr type annotation" ty
        #(tvsumm, true)
        @error "Unsupported Expr type annotation" ty typeof(ty)
        throw(TypesAnlsUnsupportedTypeAnnotation(ty))
    end
end

collectTyVarsSummary!(
    ty :: LineNumberNode,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = (tvsumm, false)

collectTyVarsSummary!(
    ty :: QuoteNode,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = (tvsumm, true)
# conservatively assuming that something relevant may be in the quote

#--------------------------------------------------
# Where type
#--------------------------------------------------

collectTyVarsSummaryWhere!(
    body :: JlASTTypeExpr, tvDecl :: JlASTTypeExpr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    (name, lb, ub) = splitTyVarDecl(tvDecl) # type var info
    envLB = envpushconstr(env, TCLoBnd)
    (_, prblb) = collectTyVarsSummary!(lb, envLB, tvsumm)
    envUB = envpushconstr(env, TCUpBnd)
    (_, prbub) = collectTyVarsSummary!(ub, envUB, tvsumm)
    envBody = envpushconstr(env, TCWhere)
    tv = TyVarInfo(name, lb, ub)
    envBody = envadd(envBody, tv)
    (_, prbbd) = collectTyVarsSummary!(body, envBody, tvsumm)
    push!(tvsumm, TyVarSummary(name, lb, ub, tv.occurrs))
    (tvsumm, prblb || prbub || prbbd)
end

splitTyVarDecl(tvDecl :: Symbol) =
    (tvDecl, DEFAULT_LB, DEFAULT_UB)

splitTyVarDecl(tvDecl :: Expr) = begin
    name = ANONYMOUS_TY_VAR
    lb = DEFAULT_LB
    ub = DEFAULT_UB
    if tvDecl.head == :(<:)
        @assert (length(tvDecl.args) == 2 && tvDecl.args[1] isa Symbol) "Unsupported var-ub format" tvDecl
        name = tvDecl.args[1]
        ub = tvDecl.args[2]
    elseif tvDecl.head == :(>:)
        @assert (length(tvDecl.args) == 2 && tvDecl.args[1] isa Symbol) "Unsupported var-lb format" tvDecl
        name = tvDecl.args[1]
        lb = tvDecl.args[2]
    else
        @assert tyVarDeclIsComparison(tvDecl) "Unsupported lb-var-ub format" tvDecl
        name = tvDecl.args[3]
        lb = tvDecl.args[1]
        ub = tvDecl.args[5]
    end
    (name, lb, ub)
end

tyVarDeclIsComparison(tvDecl :: Expr) = tvDecl.head == :comparison && 
    length(tvDecl.args) == 5 && tvDecl.args[3] isa Symbol &&
    tvDecl.args[2] == :(<:) && tvDecl.args[4] == :(<:)

#--------------------------------------------------
# ...{...} type
#--------------------------------------------------

collectTyVarsSummaryCurly!(
    curlyArgs :: Vector,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    problemEncountered = false
    constr = TCInvar
    if curlyArgs[1] == :Tuple
        constr = TCTuple
    elseif curlyArgs[1] == :Union
        constr = TCUnion
    elseif curlyArgs[1] isa Symbol
        tvInfo = envlookup(env, curlyArgs[1])
        if tvInfo !== nothing # variable occurrence
            push!(tvInfo.occurrs, tvInfo.currPos)
            constr = TCVar
        end
    elseif curlyArgs[1] isa Expr && (
        curlyArgs[1].head == :(.) || # qualified name
        curlyArgs[1].head == :($))   # escape symbol   
        # conservatively assuming invariant constructor
    elseif curlyArgs[1] isa QuoteNode
        # conservatively assuming invariant constructor
    else
        #@assert false "Unsupported target of {...} $(curlyArgs[1])"    
        @warn "Unsupported target of {...}" curlyArgs[1]
        problemEncountered = true
        # conservatively assuming invariant constructor
    end
    envArg = envpushconstr(env, constr)
    for i in 2:length(curlyArgs)
        (_, problem) = collectTyVarsSummary!(curlyArgs[i], envArg, tvsumm)
        problem && (problemEncountered = true)
    end
    (tvsumm, problemEncountered)
end
