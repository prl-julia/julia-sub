#######################################################################
# Analyzing type declarations
###############################
#
# The actual analysis will be done by the analysis for use-site variance;
# this file only prepares type declarations and transforms them to full types
# amenable by further analysis.
#
#######################################################################

"""
    (JlASTTypeExpr, JlASTTypeExpr) → (JlASTTypeExpr, JlASTTypeExpr)

Using type parameters of `tyDecl`, wraps:
- `tyDecl` (type declaration proper) into a where-type with the parameters
  in the reversed order;
- the number of type variables;
- `super` (declared supertype of `tyDecl`) into a where-type with bare
  parameters (i.e. type vars without bounds) in the reversed order.

E.g. for `(Foo{X,Y<:Ref{X}}, Bar{X})`,
returns `(Foo{X,Y} where Y<:Ref{X} where X, Bar{X} where Y where X)`.

We don't preserve bounds on type variables for the supertype because
eventually, we are interested on non-use-site-variance shape of the supertype
itself, so we don't want to pollute that info with bounds that are already
accounted for in the type declaration itself.
"""
tyDeclAndSuper2FullTypes(tyDecl :: JlASTTypeExpr, super :: JlASTTypeExpr) = begin
    (tyDeclBare, tyArgs, tyArgsBare) = splitTyDecl(tyDecl)
    (
        wrapTyInWhere(tyDeclBare, tyArgs), 
        length(tyArgs), 
        wrapTyInWhere(super, tyArgsBare)
    )
end

wrapTyInWhere(ty :: JlASTTypeExpr, varDecls :: Vector) = 
    foldr(wrapTyInWhere, varDecls; init=ty)

wrapTyInWhere(varDecl :: JlASTTypeExpr, ty :: JlASTTypeExpr) = 
    :($ty where $varDecl)

"""
    (JlASTTypeExpr) → (JlASTTypeExpr, Vector{JlASTTypeExpr})

Extracts type parameters from `tyDecl` and returns a tuple of:
- type declaration with variable names only (without bounds)
- original type parameter declarations
- variable names (without bounds)

E.g. for `Foo{Int<:X<:Number, Y<:Vector{X}}`, returns
`(Foo{X, Y}, [Int<:X<:Number, Y<:Vector{X}])`
"""
splitTyDecl(tyDecl :: JlASTTypeExpr) :: Tuple = begin
    if @capture(tyDecl, N_{ARGS__})
        varsOnly = map(extractVarName, ARGS)
        ( :($N{$(varsOnly...)}), ARGS, varsOnly )
    else
        (tyDecl, [], [])
    end
end

extractVarName(varDecl :: JlASTTypeExpr) :: Symbol = 
    if @capture(varDecl, LB_<:V_<:UB_)
        V
    elseif @capture(varDecl, V_<:UB_)
        V
    elseif @capture(varDecl, V_>:LB_)
        V
    else
        varDecl
    end