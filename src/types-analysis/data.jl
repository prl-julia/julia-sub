#######################################################################
# Data types for the analysis of type annotations
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extracting type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"Type of AST expression representing a Julia type"
JlASTTypeExpr = Any

"""
Kind of a type annotation:
- complete method type signature (without return type)
- return type
- type assertion (in the method body)
"""
@enum TypeAnnKind mtsig retty tyass

"Information about a type annotation in some file"
struct TypeAnnInfo
    funName :: JlASTTypeExpr
    kind    :: TypeAnnKind
    tyExpr  :: JlASTTypeExpr
end

"List of type annotation infos"
TypeAnnInfoList = LinkedList{TypeAnnInfo}

"Data returned by `MacroTools.splitdef`"
SplitFunDef = Dict{Symbol, Any}


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Base functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Equality
#--------------------------------------------------

Base.:(==)(v1 :: TypeAnnInfo, v2 :: TypeAnnInfo) = structEqual(v1, v2)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extra functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

csvLineString(ta :: TypeAnnInfo) =
    join(
        map(v -> "\"" * string(v) * "\"", Any[ta.funName, ta.kind, ta.tyExpr]),
        ","
    ) * "\n"
