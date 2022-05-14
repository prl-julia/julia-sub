
include("data.jl")

# Checks if the expression represents a function definition
# Copies https://github.com/FluxML/MacroTools.jl/blob/639d1a62c3d6bc37325cddbaa13d4c993d1448fb/src/utils.jl#L292-L294
isFunDef(expr) :: Bool = begin
    @capture(
        MacroTools.longdef1(expr),
        function (fcall_ | fcall_) body_ end
    )
end

collectTypeAnnotations(expr) = begin
    isFunDef(expr) || return expr
    funDefParts = splitdef(expr)
    methodArgTuple = getMethodTupleType(funDefParts)

end

# getMethodTupleType :: SplitFunDef → Expr
# Returns AST of the tuple type corresponding to the method signature
# of the method represented by `splitFDef`
getMethodTupleType(splitFDef :: SplitFunDef) :: Expr =
    combineTupleType!(
        map(getArgTypeAnn, vcat(splitFDef[:args], splitFDef[:kwargs])),
        splitFDef[:whereparams]
    )

# combineTupleType :: Any[], Tuple → Expr
# Returns AST of the tuple type combined from `argTypes` and `whereParams`
# EFFECT: modifies `argTypes` 
combineTupleType!(argTypes :: Vector, whereParams :: Tuple) :: Expr = begin
    insert!(argTypes, 1, :Tuple)
    tuple = Expr(:curly, argTypes...)
    if length(whereParams) == 0
        tuple
    else
        foldr(
            (whereParam, innerTuple) -> Expr(:where, innerTuple, whereParam),
            whereParams;
            init=tuple
        )
    end
end

# getArgTypeAnn :: Expr → TypeExpr|nothing
# Returns a type annotation corresponding to the argument `arg`.
# `arg` is either a regular or a keyword argument.

# (x) → Any
getArgTypeAnn(arg :: Symbol) =
    :Any
# (x :: T)|(x :: T = 0) → T
getArgTypeAnn(arg :: Expr) = begin
    if arg.head == :(::)
        arg.args[2]
    elseif arg.head == :(kw) # kw means default value
        getArgTypeAnn(arg.args[1])
    else
        nothing
    end
end

