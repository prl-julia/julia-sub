#######################################################################
# Data types for the analysis of type annotations
# and user-defined type declarations
#######################################################################

"Type of AST expression representing a Julia type"
JlASTTypeExpr = Any

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extracting type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""
Kind of a type annotation:
- complete method type signature (without return type)
- return type
- type assertion (in the method body) or type annotation (in the field)
"""
@enum TypeAnnKind mtsig retty tyassorann

"Information about a type annotation"
struct TypeAnnInfo
    funName :: JlASTTypeExpr
    kind    :: TypeAnnKind
    tyExpr  :: JlASTTypeExpr
end

"List of type annotation infos"
TypeAnnInfoList = LinkedList{TypeAnnInfo}

"Data returned by `MacroTools.splitdef`"
SplitFunDef = Dict{Symbol, Any}

NOTAFUNSIG = "<NOT A FUNSIG>"


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extracting type declarations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""
Kind of a user-defined type declaration:
- abstract type
- primitive type
- struct
- mutable struct
"""
@enum TypeDeclKind tdabst tdprim tdstrc tdmtbl

"Information about a user-defined type declaration"
struct TypeDeclInfo
    kind    :: TypeDeclKind
    tyDecl  :: JlASTTypeExpr
    tySuper :: JlASTTypeExpr
    # name    :: Symbol
    # tyargs  :: JlASTTypeExpr
end

"List of type declaration infos"
TypeDeclInfoList = LinkedList{TypeDeclInfo}


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# All type info
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

struct TypeInfo
    tyAnns  :: TypeAnnInfoList
    tyDecls :: TypeDeclInfoList
end

TypeInfo() = TypeInfo(nil(TypeAnnInfo), nil(TypeDeclInfo))

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analyzing type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"""
Kind of type constructor
- TCVar means that the variable is used as a target of {}, e.g. X{Int} where X
- TCLBVar1 means that the variable has a single anonymous usage in lower bound, e.g. Ref{>:Int}
"""
@enum TypeConstructor TCTuple TCInvar TCUnion TCWhere TCLoBnd TCUpBnd TCVar TCLBVar1 TCUBVar1 TCCall TCMCall

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
    context :: TypeConstrStack
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
    DataStructures.head(env).name == name ?
    DataStructures.head(env) :
        envlookup(DataStructures.tail(env), name)
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
# Converting short-hand types into complete form
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@enum TypeTransformationKind TTok TTlb TTub

struct TypeTransInfo
    kind  :: TypeTransformationKind
    expr  :: JlASTTypeExpr
    bound :: Union{JlASTTypeExpr, Nothing} # !== nothing only if kind != TTok
end

TypeTransInfo(kind :: TypeTransformationKind, expr :: JlASTTypeExpr) =
    TypeTransInfo(kind, expr, nothing)

TypeTransInfo(expr :: JlASTTypeExpr) =
    TypeTransInfo(TTok, expr)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Base functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Equality
#--------------------------------------------------

Base.:(==)(v1 :: TypeAnnInfo,   v2 :: TypeAnnInfo)      = structEqual(v1, v2)

Base.:(==)(v1 :: TypeDeclInfo,  v2 :: TypeDeclInfo)     = structEqual(v1, v2)

Base.:(==)(v1 :: TypeInfo,      v2 :: TypeInfo)         = structEqual(v1, v2)

Base.:(==)(v1 :: TyVarInfo,     v2 :: TyVarInfo)        = structEqual(v1, v2)

Base.:(==)(v1 :: TyVarSummary,  v2 :: TyVarSummary)     = structEqual(v1, v2)

Base.:(==)(v1 :: TypeTransInfo, v2 :: TypeTransInfo)    = structEqual(v1, v2)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extra functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

csvLineString(ta :: TypeAnnInfo) =
    join(
        map(v -> "\"" * string(v) * "\"", Any[ta.funName, ta.kind, ta.tyExpr]),
        ","
    ) * "\n"
    

