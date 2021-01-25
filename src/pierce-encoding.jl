abstract type FSubType end
struct FSubVar <: FSubType
	name::Symbol
end
struct FSubTop <: FSubType end
struct FSubUni <: FSubType
	binding::Symbol
	ub::FSubType
	body::FSubType
end


subst(var::Symbol, fort::FSubType, int::FSubTop) = int
subst(var::Symbol, fort::FSubType, int::FSubVar) = if int.name==var fort else int end
function subst(var::Symbol, fort::FSubType, int::FSubUni)
	if int.binding == var
		return int
	end
	return FSubUni(int.binding, subst(var, fort, int.ub), subst(var, fort, int.body))
end


fsub(a::FSubType, b::FSubTop, env::Dict{Symbol, FSubType})=true
fsub(a::FSubVar, b::FSubTop, env::Dict{Symbol, FSubType})=true
function fsub(a::FSubVar, b::FSubType, env::Dict{Symbol, FSubType})
	if b isa FSubVar && a.name == b.name
		return true
	end
	return fsub(env[a.name], b, env)
end
function fsub(a::FSubUni, b::FSubUni, env::Dict{Symbol, FSubType})
	if !fsub(b.ub, a.ub, env)
		return false
	end
	nsvar = gensym(a.binding)
	nvar = FSubVar(nsvar)
	na = subst(a.binding, nvar, a.body)
	nb = subst(b.binding, nvar, b.body)
	env[nsvar] = b.ub
	return fsub(na, nb, env)
end
function fsub(a::FSubType, b::FSubType, env::Dict{Symbol, FSubType})
	println("Failed at $env |- $a <: $b")
	return false
end



function enc(v::FSubVar, eenv::Dict{Symbol,TypeVar})
	return eenv[v.name] # from Ref{...} ; check that not invariant
end
function enc(v::FSubTop, eenv::Dict{Symbol, TypeVar})
	return Union{}
end
function enc(v::FSubUni, eenv::Dict{Symbol, TypeVar})
	nvn = TypeVar(gensym(v.binding))
	lb = enc(v.ub, eenv)
	nvn.lb = lb
	eenv[v.binding] = nvn
	return UnionAll(nvn, Tuple{Ref{nvn}, enc(v.body, eenv)})
end
function enc(v::FSubType)
	return enc(v, Dict{Symbol, TypeVar}())
end

function esub(a::FSubType,b::FSubType)
	return enc(b) <: enc(a)
end
function enc(env::Dict{Symbol,FSubType})
	return Dict(k => begin nvn = TypeVar(gensym(k)); nvn.lb = enc(v); nvn end for (k,v) in env)
end

function esub(a::FSubType, b::FSubType, env::Dict{Symbol,FSubType})
	tenv = enc(env)
	A = enc(b, tenv)
	B = enc(a, tenv)
	lhs = foldl((t,v) -> UnionAll(v,t), values(tenv); init=Tuple{Ref{A}, Ref{V} where V>:B})
	rhs = (Tuple{Ref{T}, Ref{V} where V>:T} where T)
	return lhs <: rhs
end
 
fsnot(a::FSubType) = begin isym=gensym(:notv); FSubUni(isym, a, FSubVar(isym)) end
theta = FSubUni(:a, FSubTop(), fsnot(FSubUni(:b, FSubVar(:a), fsnot(FSubVar(:b)))))
ge = Dict{Symbol, FSubType}(:a0=>theta)
gl = FSubVar(:a0)
gr = FSubUni(:a1, FSubVar(:a0), fsnot(FSubVar(:a1)))

esub(gl, gr, ge)