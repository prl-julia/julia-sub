#######################################################################
# Extracting type declarations from the source code
###############################
#
# The goal is to extract user-defined type declarations,
# in particular, declared supertypes.
#
# Here, we are not interested in type annotations on fields,
# because those are processed by types-extract.jl.
#
#######################################################################

"""
    :: Any → TypeDeclInfoList
Collects type declarations in `expr`
"""
collectTypeDeclarations(expr) :: TypeDeclInfoList = begin
    tyDecls = nil(TypeDeclInfo)
    recordTyDecls(e) = begin
        try 
            (e, tyDecls) = collectTypeDeclaration(e, tyDecls)
        catch err
            @error "Couldn't process expression" e err
        end
        e # return for `prewalk` to work
    end
    MacroTools.prewalk(recordTyDecls, expr)
    tyDecls
end

"""
    :: (Any, TypeDeclInfoList) → (Any, TypeDeclInfoList)

If `expr` is not a type declaration, returns:
- `expr` as is
- `tyDecls` as is
Otherwise, returns:
- the empty expression `:()`
- the type declaration represented by `expr` concatenated with `tyDecls``
"""
collectTypeDeclaration(expr, tyDecls :: TypeDeclInfoList) = begin
    kind    = tdabst
    tyDecl  = :()
    tySuper = :Any
    # TD    stands for the declaration itself,
    # S     stands for the declared supertype,
    # F     stands for fields
    # E.g. `Foo{X} <: Bar` => TD is Foo{X}, S is Bar.
    # If no supertype is provided, tySuper defaults to Any]
    if @capture(expr, abstract type TD_ <: S_ end)
        (kind, tyDecl, tySuper) = (tdabst, TD, S)
    elseif @capture(expr, abstract type TD_ end)
        (kind, tyDecl) = (tdabst, TD)
    elseif @capture(expr, primitive type TD_ <: S_ B_ end)
        (kind, tyDecl, tySuper) = (tdprim, TD, S)
    elseif @capture(expr, primitive type TD_ B_ end)
        (kind, tyDecl) = (tdprim, TD)
    elseif @capture(expr, mutable struct TD_ <: S_ F_ end)
        (kind, tyDecl, tySuper) = (tdmtbl, TD, S)
    elseif @capture(expr, mutable struct TD_ F_ end)
        (kind, tyDecl) = (tdmtbl, TD)
    elseif @capture(expr, struct TD_ <: S_ F_ end)
        (kind, tyDecl, tySuper) = (tdstrc, TD, S)
    elseif @capture(expr, struct TD_ F_ end)
        (kind, tyDecl,) = (tdstrc, TD)
    else
        return (expr, tyDecls)
    end
    # We also want to extract info about arguments
    name    = Symbol("<NA-typename>")
    if @capture(tyDecl, N_{ARGS__})
        name = N
    else
        if tyDecl isa Symbol
            name = tyDecl
        else
            @error "type declaration $tyDecl is expected to be a Symbol"
        end
    end
    (   :(), 
        cons(TypeDeclInfo(
            name, kind, tyDecl, tySuper
        ), tyDecls))
end

