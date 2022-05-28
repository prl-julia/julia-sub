#######################################################################
# Extracting method type signatures from the source code
###############################
#
# The goal is to extract all type annotations from method definitions.
#
# There are 3 sources of type annotations:
#
#   1) method arguments signature (e.g. `f(x::Vector{T}) where T`
#      corresponds to `Tuple{Vector{T}} where T`)
#   2) return type annotation (e.g. `f() :: Int`)
#   3) type assertions in the method body (e.g. `x :: Int`)
#
# We start with 1) and ignore 2-3 for now.
#######################################################################

parseAndCollectTypeAnnotations(
    juliaFileName :: AbstractString
) :: TypeAnnInfoList = begin
    expr = parseJuliaFile(juliaFileName)
    collectTypeAnnotations(expr)
end

"""
    :: Any → TypeAnnInfoList
Collects type annotations from all method definitions in `expr`
"""
collectTypeAnnotations(expr) :: TypeAnnInfoList = begin
    tyAnns = nil(TypeAnnInfo)
    recordFunDefTyAnns(e) = begin
        try 
            tyAnns = collectFunDefTypeAnnotations(e, tyAnns)
        catch err
            @error "Couldn't process expression" e err
        end
        e # return the same expr for `prewalk` to work
    end
    MacroTools.prewalk(recordFunDefTyAnns, expr)
    tyAnns
end

"""
    :: (Any, TypeAnnInfoList) → TypeAnnInfoList
Returns type annotations from `expr` concatenated with the list `tyAnns`
if `expr` is a method definition.

FIXME: currently only extracts a method signature
"""
collectFunDefTypeAnnotations(expr, tyAnns :: TypeAnnInfoList) = begin
    isFunDef(expr) || return tyAnns
    funDefParts = splitdef(expr)
    methodArgTuple = getMethodTupleType(funDefParts)
    cons(
        TypeAnnInfo(
            get(funDefParts, :name, "<NA-name>"), 
            mtsig, 
            methodArgTuple
        ),
        tyAnns
    )
end

"""
    :: SplitFunDef → Expr
Returns AST of the tuple type corresponding to the method signature
of the method represented by `splitFDef`
"""
getMethodTupleType(splitFDef :: SplitFunDef) :: Expr =
    combineTupleType!(
        Vector{JlASTTypeExpr}(
            map(getArgTypeAnn, vcat(splitFDef[:args], splitFDef[:kwargs]))
        ),
        splitFDef[:whereparams]
    )

"""
    :: Expr → TypeExpr|nothing
Returns a type annotation corresponding to the parameter `arg`.
`arg` is either a regular or a keyword argument;
otherwise, `BadMethodParamAST` is thrown.
"""
function getArgTypeAnn end

"""
    (x) → :Any
"""
getArgTypeAnn(arg :: Symbol) :: JlASTTypeExpr =
    :Any
"""
    (x :: T)|(x :: T = 0) → :T
    (x = 0) → :Any
FIXME: in case of a tuple argument, only TUPLE_ARG is recorded rather than
the right type annotation
"""
getArgTypeAnn(arg :: Expr) :: JlASTTypeExpr = begin
    if arg.head == :(::)
        arg.args[end]
    elseif arg.head == :(kw)    # kw means default value
        getArgTypeAnn(arg.args[1])
    elseif arg.head == :(...)   # vararg
        tyAnn = getArgTypeAnn(arg.args[1])
        :( Vararg{$tyAnn} )
    elseif arg.head == :tuple
        :TUPLE_ARG
    else
        throw(TypesAnlsBadMethodParamAST(arg))
    end
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""
    :: Any → Bool
Checks if expression represents a function definition

Copies https://github.com/FluxML/MacroTools.jl/blob/639d1a62c3d6bc37325cddbaa13d4c993d1448fb/src/utils.jl#L292-L294
"""
isFunDef(expr) :: Bool = begin
    @capture(
        MacroTools.longdef1(expr),
        function (fcall_ | fcall_) body_ end
    )
end

"""
    :: Any[], Tuple → Expr
    ([T1, T2, ...], (X, Y, ...)) → Tuple{T1, T2, ...} where Y where X
Returns AST of the tuple type combined from `argTypes` and `whereParams`

EFFECT: modifies `argTypes`
"""
combineTupleType!(
    argTypes :: Vector{JlASTTypeExpr}, whereParams :: Tuple
) :: Expr = begin
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
