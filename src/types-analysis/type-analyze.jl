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

tyVarIsNotInLowerBound(tytvs :: TypeTyVarsSummary) = 
    all(tyVarIsNotInLowerBound, tytvs)

tyVarIsNotInLowerBound(tvs :: TyVarSummary) = 
    all(tyVarIsNotInLowerBound, map(reverse, tvs.occurrs))

tyVarIsNotInLowerBound(tvs :: TypeConstrStack) = 
    all(constr -> !(constr in [TCLoBnd, TCLBVar1]), tvs)


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


tyVarOccursAsImpredicativeUsedSiteVariance(tytvs :: TypeTyVarsSummary) = 
    all(tyVarOccursAsImpredicativeUsedSiteVariance, tytvs)

tyVarOccursAsImpredicativeUsedSiteVariance(tvs :: TyVarSummary) = begin
    useSite = tyVarOccursAsUsedSiteVariance(tvs)
    # if it doesn't look like use-site variance, check variable context:
    # we are interested in positions that are not strictly covariant
    useSite || tyVarOccIsCovariant(tvs.context)
end


tyVarOccursAsUsedSiteVariance(tytvs :: TypeTyVarsSummary) = 
    all(tyVarOccursAsUsedSiteVariance, tytvs)

"""
For wildcards-like restriction, type variable can be used only once.
Because of the diagonal rule, multiple covariant occurrences are of interest.
If a variable occurs in an invariant or cotravariant position, it cannot cross
multiple constructors after invariant (it is okay to cross covariant
constructors before the invariant one, e.g. `Tuple{Ref{T}} where T`,
because it's the same as `Tuple{Ref{T} where T}`)
"""
tyVarOccursAsUsedSiteVariance(tvs :: TyVarSummary) = begin
    isempty(tvs.occurrs) && return true
    covOccs = count(tyVarOccIsCovariant, map(reverse, tvs.occurrs))
    # either the single occurrence is covariant,
    # or the variable is bound immediately outside
    length(tvs.occurrs) == 1 &&
        (covOccs == 1 || 
         tyVarNonCovOccIsImmediate(reverse(tvs.occurrs[1])))
end

tyVarOccIsCovariant(constrStack :: TypeConstrStack) = 
    all(
        constr -> constr in [TCTuple, TCUnion, TCWhere, TCUpBnd, TCUBVar1],
        constrStack)

tyVarNonCovOccIsImmediate(constrStack :: Nil{TypeConstructor}) = true
tyVarNonCovOccIsImmediate(constrStack :: Cons{TypeConstructor}) = 
    (DataStructures.head(constrStack) in 
        [TCTuple, TCUnion, TCWhere, TCUpBnd, TCUBVar1] &&
        tyVarNonCovOccIsImmediate(DataStructures.tail(constrStack))) ||
    isempty(DataStructures.tail(constrStack))


"All vars used exactly once"
tyVarUsedOnce(tytvs :: TypeTyVarsSummary) = 
    all(tyVarUsedOnce, tytvs)

tyVarUsedOnce(tvs :: TyVarSummary) = length(tvs.occurrs) == 1


"At least one existential type is declared inside an invariant constructor"
existIsDeclaredInInv(tytvs :: TypeTyVarsSummary) = 
    any(existIsDeclaredInInv, tytvs)

existIsDeclaredInInv(tvs :: TyVarSummary) = containsInv(tvs.context)

containsInv(constrStack :: Nil{TypeConstructor}) = false
containsInv(constrStack :: Cons{TypeConstructor}) = 
    (DataStructures.head(constrStack) == TCInvar) ||
    containsInv(DataStructures.tail(constrStack))

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Summarizing type variable usage
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

collectTyVarsSummary(ty :: JlASTTypeExpr) = 
    collectTyVarsSummary!(ty, tcsempty(), envempty(), TypeTyVarsSummary())


"""
The second return value indicates if any potential problems were encountered

EFFECT: modifies `tvsumm`
"""
collectTyVarsSummary!(
    ty :: JlASTTypeExpr, context :: TypeConstrStack,
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
    ty :: Symbol, context :: TypeConstrStack,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    tvInfo = envlookup(env, ty)
    tvInfo === nothing || # ty is a variable occurrence
        push!(tvInfo.occurrs, tvInfo.currPos)
    (tvsumm, false)
end

collectTyVarsSummary!(
    ty :: Expr, context :: TypeConstrStack,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    if ty.head == :(.) # qualified name
        (tvsumm, false) # nothing to do, it's definitely not a variable occurrence
    elseif ty.head == :where
        # The process of extracting type annotations should produce where types
        # with single variables, i.e.
        # `t where X where Y`` instead of `t where {X, Y}`
        @assert length(ty.args) == 2 "Expected single variable in a where type"
        collectTyVarsSummaryWhere!(ty.args[1], ty.args[2], context, env, tvsumm)
    elseif ty.head == :curly
        @assert length(ty.args) >= 1 "Unsupported {} $ty"
        collectTyVarsSummaryCurly!(ty.args, context, env, tvsumm)
    elseif ty.head == :(<:) || ty.head == :(>:)
        @error "Shorthand forms <: >: are not expected" ty
    #=
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
    =#
    elseif ty.head == :call
        envArg = envpushconstr(env, TCCall)
        problemEncountered = false
        for arg in ty.args
            (_, problem) = collectTyVarsSummary!(arg, cons(TCCall, context), envArg, tvsumm)
            problem && (problemEncountered = true)
        end
        (tvsumm, problemEncountered)
    elseif ty.head == :macrocall
        envArg = envpushconstr(env, TCMCall)
        problemEncountered = false
        for arg in ty.args
            (_, problem) = collectTyVarsSummary!(arg, cons(TCMCall, context), envArg, tvsumm)
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
    ty :: LineNumberNode, context :: TypeConstrStack,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = (tvsumm, false)

collectTyVarsSummary!(
    ty :: QuoteNode, context :: TypeConstrStack,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = (tvsumm, true)
# conservatively assuming that something relevant may be in the quote

#--------------------------------------------------
# Where type
#--------------------------------------------------

collectTyVarsSummaryWhere!(
    body :: JlASTTypeExpr, tvDecl :: JlASTTypeExpr, context :: TypeConstrStack,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    (name, lb, ub) = splitTyVarDecl(tvDecl) # type var info
    envLB = envpushconstr(env, TCLoBnd)
    (_, prblb) = collectTyVarsSummary!(lb, cons(TCLoBnd, context), envLB, tvsumm)
    envUB = envpushconstr(env, TCUpBnd)
    (_, prbub) = collectTyVarsSummary!(ub, cons(TCUpBnd, context), envUB, tvsumm)
    envBody = envpushconstr(env, TCWhere)
    tv = TyVarInfo(name, lb, ub)
    envBody = envadd(envBody, tv)
    (_, prbbd) = collectTyVarsSummary!(body, cons(TCWhere, context), envBody, tvsumm)
    push!(tvsumm, TyVarSummary(name, lb, ub, tv.occurrs, context))
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
    curlyArgs :: Vector, context :: TypeConstrStack,
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
        (_, problem) = collectTyVarsSummary!(curlyArgs[i], cons(constr, context), envArg, tvsumm)
        problem && (problemEncountered = true)
    end
    (tvsumm, problemEncountered)
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Converting short-hand types into complete form
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

transformShortHand(ty :: JlASTTypeExpr) :: TypeTransInfo = 
    isprimitivetype(typeof(ty)) || ty isa String ?
    TypeTransInfo(ty) :
    begin
        #@warn "Unsupported type annotation" ty
        @error "Unsupported type annotation in shorthand" ty typeof(ty)
        throw(TypesAnlsUnsupportedTypeAnnotation(ty))
    end

transformShortHand(ty :: Symbol) = TypeTransInfo(ty)

transformShortHand(ty :: Expr) = begin
    if ty.head == :curly
        @assert length(ty.args) >= 1 "Unsupported {} $ty"
        # the first argument is a receiver on the left: it shouldn't contain
        # any shorthands
        curlyRecvTr = transformShortHand(ty.args[1])
        @assert curlyRecvTr.kind == TTok "Receiver of {...} shouldn't contain shorthand type variables"
        # transform other arguments and combine into a where type
        appArgTransforms = map(transformShortHand, ty.args[2:end])
        ty = Expr(
            ty.head, curlyRecvTr.expr,
            map(argtr -> argtr.expr, appArgTransforms)...)
        for argTr in appArgTransforms
            if argTr.kind == TTlb
                ty = :($ty where $(argTr.expr) >: $(argTr.bound))
            elseif argTr.kind == TTub
                ty = :($ty where $(argTr.expr) <: $(argTr.bound))
            end
        end
        TypeTransInfo(ty)
    elseif ty.head == :(<:) && length(ty.args) == 1 # <:ub like in Ref{<:ub}
        newVar = gensym(ANONYMOUS_TY_VAR)
        boundTr = transformShortHand(ty.args[1])
        @assert boundTr.kind == TTok "Unexpected transformation in upper bound" ty boundTr
        TypeTransInfo(TTub, newVar, boundTr.expr)
    elseif ty.head == :(>:) && length(ty.args) == 1 # >:lb like in Ref{>:ub}
        newVar = gensym(ANONYMOUS_TY_VAR)
        boundTr = transformShortHand(ty.args[1])
        @assert boundTr.kind == TTok "Unexpected transformation in lower bound" ty boundTr
        TypeTransInfo(TTlb, newVar, boundTr.expr)
    else 
        # simply call transformation recursively
        ty = Expr(ty.head, map(
            arg -> transformShortHand(arg).expr,
            ty.args)...
        )
        # unroll where if applicable
        if ty.head == :where
            @assert length(ty.args) >= 2 "Where with at least 2 parts is expected" ty
            if length(ty.args) > 2
                tyNew = Expr(:where, ty.args[1], ty.args[2])
                extraWheres = ty.args[3:end]
                for tv in extraWheres
                    tyNew = :($tyNew where $tv)
                end
                return TypeTransInfo(tyNew)
            end
        end
        TypeTransInfo(ty)
    end
end

transformShortHand(ty :: LineNumberNode) = TypeTransInfo(ty)

transformShortHand(ty :: QuoteNode) = TypeTransInfo(ty)
