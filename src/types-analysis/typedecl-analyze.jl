#######################################################################
# Analyzing type declarations
###############################
#
# Relies on type annotations analysis for use-site variance
#
#######################################################################

"""
    (JlASTTypeExpr, JlASTTypeExpr) → (JlASTTypeExpr, JlASTTypeExpr)

Using type parameters of `tyDecl`,
wraps `tyDecl` (type declaration proper) and
`super` (its declared supertype)
into where-types with the parameters in the reversed order.
E.g. for `(Foo{X,Y<:Ref{X}}, Bar{X})`,
returns `(Foo{X,Y} where Y<:Ref{X} where X, Bar{X} where X)`.
"""
tyDeclAndSuper2FullTypes(tyDecl :: JlASTTypeExpr, super :: JlASTTypeExpr) = begin
    (tyDeclBare, tyArgs) = splitTyDecl(tyDecl)
    (wrapTyInWhere(tyDeclBare, tyArgs), wrapTyInWhere(super, tyArgs))
end

wrapTyInWhere(ty :: JlASTTypeExpr, varDecls :: Vector) = 
    foldr(wrapTyInWhere, varDecls; init=ty)

wrapTyInWhere(varDecl :: JlASTTypeExpr, ty :: JlASTTypeExpr) = 
    :($ty where $varDecl)

"""
    (JlASTTypeExpr) → (JlASTTypeExpr, Vector{JlASTTypeExpr})

Extracts type parameters from `tyDecl` and returns a pair of:
- type declaration with variable names only (without bounds)
- original type parameter declarations

E.g. for `Foo{Int<:X<:Number, Y<:Vector{X}}`, returns
`(Foo{X, Y}, [Int<:X<:Number, Y<:Vector{X}])`
"""
splitTyDecl(tyDecl :: JlASTTypeExpr) :: Tuple = begin
    if @capture(tyDecl, N_{ARGS__})
        varsOnly = map(extractVarName, ARGS)
        ( :($N{$(varsOnly...)}), ARGS )
    else
        (tyDecl, [])
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