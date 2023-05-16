#######################################################################
# Extracting method type signatures from the source code
###############################
#
# The goal is to extract all type annotations from method definitions
# and field declarations.
#
# There are 4 sources of type annotations:
#
#   1) method arguments signature (e.g. `f(x::Vector{T}) where T`
#      corresponds to `Tuple{Vector{T}} where T`)
#   2) return type annotation (e.g. `f() :: Int`)
#   3) type assertions in the method body (e.g. `x :: Int`)
#   4) field type annotations
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
    recordTyAnns(e) = begin
        try 
            if isFunDef(e)
                (e, tyAnns) = collectFunDefTypeSignature(e, tyAnns)
            end
            (e, tyAnns) = collectDeclaredTypeAnnotation(e, tyAnns)
        catch err
            @error "Couldn't process expression" e err
        end
        e # return for `prewalk` to work
    end
    MacroTools.prewalk(recordTyAnns, expr)
    tyAnns
end

"""
    :: (Any, TypeAnnInfoList) → (Any, TypeAnnInfoList)
ASSUME: `expr` is a method definition.

Returns:
- the body of the method encoded by `expr`
- method signature type and return type (if present) concatenated
  with the list `tyAnns`.
"""
collectFunDefTypeSignature(expr, tyAnns :: TypeAnnInfoList) = begin
    funDefParts = splitdef(expr)
    methodArgTuple = getMethodTupleType(funDefParts)
    fname = get(funDefParts, :name, "<NA-name>")
    tyAnns = cons(
        TypeAnnInfo(fname, mtsig, methodArgTuple),
        tyAnns)
    if haskey(funDefParts, :rtype)
        tyAnns = cons(
            TypeAnnInfo(fname, retty, funDefParts[:rtype]),
            tyAnns)
    end
    (get(funDefParts, :body, "<NA-body>"), tyAnns)
end

"""
    :: (Any, TypeAnnInfoList) → (Any, TypeAnnInfoList)
ASSUME: `expr` is NOT a method definition
(nothing bad happens if it is a method definition, but this method is supposed
to be called for something else to avoid the collection of duplicate annotations)

Returns:
- `expr` as is or with the type annotation removed if it had one
- type annotation `ty` if `expr` is `e :: ty` concatenated
  with the list `tyAnns`, or `tyAnns` otherwise
"""
collectDeclaredTypeAnnotation(expr, tyAnns :: TypeAnnInfoList) = begin
    if @capture(expr, E_ :: TY_)
        tyAnns = cons(TypeAnnInfo(NOTAFUNSIG, tyassorann, TY), tyAnns)
        expr = E
    end
    (expr, tyAnns)
end

"""
    :: SplitFunDef → Expr
Returns AST of the tuple type corresponding to the method signature
of the method represented by `splitFDef`
"""
getMethodTupleType(splitFDef :: SplitFunDef) :: Expr = begin
    args = splitFDef[:args]
    if length(args) == 1 && args[1] isa Expr && args[1].head == :parameters
        args = args[1].args
    end
    combineTupleType!(
        Vector{JlASTTypeExpr}(
            map(getArgTypeAnn, vcat(args, splitFDef[:kwargs]))
        ),
        splitFDef[:whereparams]
    )
end

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
    elseif arg.head == :macrocall
        arg.args[1] == :(@nospecialize) ? :NOSPECIALIZE : :MACROCALL
    elseif arg.head == :call
        :CALL
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
