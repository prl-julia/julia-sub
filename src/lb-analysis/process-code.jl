#######################################################################
# Analysing code
###############################
#
# The goal is to find all occurrences of lower bounds
#   on type variables.
#
# This can happen in 2 cases:
#   1) where T >: Int
#   2) where Int <: T <: Number
# So first, we need to look for both `>:` and `<:` textually
#
# If at least one of those is present, parsing Julia code
#   can give more precise results
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Simple search of text for `<:` and `>:`
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# For Julia < 1.3 compatibility
if VERSION < v"1.3"
    Base.count(pattern :: String, string :: String) =
        sum(map(_ -> 1, eachmatch(Regex(pattern), string)))
end

# Returns the number of occurences of constraint `constr` in `text`
countTextualConstr(constr :: ConstrKind, text :: String) =
    count(CONSTRAINT_PATTERN[constr], text)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Parsing and detecting lower bounds
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Any → LowerBound|nothing
# If `expr` is an expression that directly contains a lower bound,
# returns it; otherwise, returns `nothing`
# NOTE: Matches two patterns: `T>:LB` and `LB<:T<:UB`
#   Although syntactically it's possible to write `UB>:T` or `UB>:T>:LB`,
#   Julia doesn't accept such syntax
extractLowerBound(expr) = begin
    hasLB = @capture(expr, T_ >: LB_)
    hasLB && return LB # if the first pattern worked, we are done
    hasLB = @capture(expr, LB_ <: T_ <: UB_)
    hasLB && return LB
    nothing # if neither pattern worked out
end

extractLowerBounds(expr) = begin
    bounds = Multiset()
    # we need to capture new state, so the local function
    # closes over `bounds`
    recordLBs(e) = begin
        lb = extractLowerBound(e)
        # if there is bound, save it
        lb === nothing || push!(bounds, lb)
        # return the same expr for `prewalk` to work
        e
    end
    MacroTools.prewalk(recordLBs, expr)
    bounds
end