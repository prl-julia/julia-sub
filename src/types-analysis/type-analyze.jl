#######################################################################
# Analyzing type annotations for their type variables usage
###############################
#
# TODO 
#
#######################################################################

const ANONYMOUS_TYPE_VARIABLE = :ANON_TV

collectTyVarsSummary(ty :: JlASTTypeExpr) = 
    collectTyVarsSummary!(ty, envempty(), TypeTyVarsSummary())


"""

EFFECT: modifies `tvsumm`
"""
collectTyVarsSummary!(
    ty :: JlASTTypeExpr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = throw(TypesAnlsUnsupportedTypeAnnotation(ty))

#=
collectTyVarsSummary!(
    ty :: JlASTTypeExpr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    
end
=#

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
    tvsumm
end

collectTyVarsSummary!(
    ty :: Expr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    if ty.head == :(.) # qualified name
        tvsumm # nothing to do, it's definitely not a variable occurrence
    elseif ty.head == :where
        # The process of extracting type annotations should produce where types
        # with single variables, i.e.
        # `t where X where Y`` instead of `t where {X, Y}`
        @assert length(ty.args) == 2 "Expected single variable in a where type"
        collectTyVarsSummaryWhere!(ty.args[1], ty.args[2], env, tvsumm)
    elseif ty.head == :curly
        @assert length(ty.args) >= 1 "Unsupported {} $ty"
        collectTyVarsSummaryCurly!(ty.args, env, tvsumm)
    else
        throw(TypesAnlsUnsupportedTypeAnnotation(ty))
    end
end

#--------------------------------------------------
# Where type
#--------------------------------------------------

collectTyVarsSummaryWhere!(
    body :: JlASTTypeExpr, tvDecl :: JlASTTypeExpr,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
    (name, lb, ub) = splitTyVarDecl(tvDecl) # type var info
    envLB = envpushconstr(env, TCLoBnd)
    collectTyVarsSummary!(lb, envLB, tvsumm)
    envUB = envpushconstr(env, TCUpBnd)
    collectTyVarsSummary!(ub, envUB, tvsumm)
    envBody = envpushconstr(env, TCWhere)
    tv = TyVarInfo(name, lb, ub)
    envBody = envadd(envBody, tv)
    collectTyVarsSummary!(body, envBody, tvsumm)
    push!(tvsumm, TyVarSummary(name, lb, ub, tv.occurrs))
    tvsumm
end

splitTyVarDecl(tvDecl :: Symbol) =
    (tvDecl, DEFAULT_LB, DEFAULT_UB)

splitTyVarDecl(tvDecl :: Expr) = begin
    name = ANONYMOUS_TYPE_VARIABLE
    lb = DEFAULT_LB
    ub = DEFAULT_UB
    if tvDecl.head == :(<:)
        @assert (length(tvDecl.args) == 2 && tvDecl.args[1] isa Symbol) "Unsupported var-ub format $tvDecl"
        name = tvDecl.args[1]
        ub = tvDecl.args[2]
    elseif tvDecl.head == :(>:)
        @assert (length(tvDecl.args) == 2 && tvDecl.args[1] isa Symbol) "Unsupported var-lb format $tvDecl"
        name = tvDecl.args[1]
        lb = tvDecl.args[2]
    else
        @assert tyVarDeclIsComparison(tvDecl) "Unsupported lb-var-ub format $tvDecl"
        name = tvDecl.args[3]
        lb = tvDecl.args[1]
        ub = tvDecl.args[5]
    end
    (name, lb, ub)
end

tyVarDeclIsComparison(tvDecl :: Expr) = tvDecl.head == :comparison && 
    length(tvDecl.args) == 5 && tvDecl.args[3] isa Symbol &&
    tvDecl.args[2] == :(<:) && tvDecl.args[4] == :(>:)

#--------------------------------------------------
# ...{...} type
#--------------------------------------------------

collectTyVarsSummaryCurly!(
    curlyArgs :: Vector,
    env :: TyVarEnv, tvsumm :: TypeTyVarsSummary
) = begin
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
    else
        @assert false "Unsupported target of {...} $(curlyArgs[1])"    
    end
    envArg = envpushconstr(env, constr)
    for i in 2:length(curlyArgs)
        collectTyVarsSummary!(curlyArgs[i], envArg, tvsumm)
    end
    tvsumm
end
