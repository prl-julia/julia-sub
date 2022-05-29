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
# Analyzing type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"Kind of type constructor"
@enum TypeConstructor TCTuple TCInvar TCUnion TCWhere TCLoBnd TCUpBnd TCVar

"Stack of type constructors"
TypeConstrStack = LinkedList{TypeConstructor}

tcsempty() = nil(TypeConstructor)


const DEFAULT_LB = :(Union{})
const DEFAULT_UB = :Any

"""
Information about a type variable in environment
- `name`
- `lb` lowerbound
- `ub` upperbound
- `currPos` keeps track of the current stack of type constructors from
  the place where the variable was introduced; the outermost constructor
  in the stack corresponds to the current position in the type
  (e.g. `-` for `Exists X.Tuple{Ref{-}}` is `Inv->Tuple->Nil`)
- `occurrs` keeps track of every occurrence described as a stack
"""
struct TyVarInfo
    name    :: Symbol
    lb      :: JlASTTypeExpr
    ub      :: JlASTTypeExpr
    currPos :: TypeConstrStack
    occurrs :: Vector{TypeConstrStack}
end

TyVarInfo(name :: Symbol, lb :: JlASTTypeExpr, ub :: JlASTTypeExpr) =
    TyVarInfo(
        name, lb, ub,
        tcsempty(), TypeConstrStack[]
    )
TyVarInfo(name :: Symbol) = TyVarInfo(name, DEFAULT_LB, DEFAULT_UB)


TyVarEnv = LinkedList{TyVarInfo}


struct TyVarSummary
    name    :: Symbol
    lb      :: JlASTTypeExpr
    ub      :: JlASTTypeExpr
    occurrs :: Vector{TypeConstrStack}
end

TypeTyVarsSummary = Vector{TyVarSummary}

#--------------------------------------------------
# Type variable environment utilities
#--------------------------------------------------

envempty() = nil(TyVarInfo)

envlookup(
    env :: TyVarEnv, name :: Symbol
) :: Union{TyVarInfo, Nothing} = begin
    isempty(env) && return nothing
    head(env).name == name ?
        head(env) :
        envlookup(tail(env), name)
end

envadd(env :: TyVarEnv, tv :: TyVarInfo) = cons(tv, env)

envpushconstr(
    env :: TyVarEnv, constr :: TypeConstructor
) :: TyVarEnv = begin
    map(
        tv -> TyVarInfo(
            tv.name, tv.lb, tv.ub,
            cons(constr, tv.currPos), tv.occurrs
        ),
        env
    )
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Base functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Equality
#--------------------------------------------------

Base.:(==)(v1 :: TypeAnnInfo,  v2 :: TypeAnnInfo)   = structEqual(v1, v2)

Base.:(==)(v1 :: TyVarInfo,    v2 :: TyVarInfo)     = structEqual(v1, v2)

Base.:(==)(v1 :: TyVarSummary, v2 :: TyVarSummary)  = structEqual(v1, v2)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extra functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

csvLineString(ta :: TypeAnnInfo) =
    join(
        map(v -> "\"" * string(v) * "\"", Any[ta.funName, ta.kind, ta.tyExpr]),
        ","
    ) * "\n"
