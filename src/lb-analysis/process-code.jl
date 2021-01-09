#######################################################################
# Analysing expressions for lower bounds
###############################
#
# The goal is to find all occurrences of lower bounds
#   on type variables in expresions.
#
# This can happen in 2 cases:
#   1) where T >: Int
#   2) where Int <: T <: Number
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Parsing and detecting lower bounds
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Any → LowerBound|nothing
# If `expr` is an expression that directly contains a lower bound,
# returns it; otherwise, returns `nothing`
# NOTE: Matches two patterns: `T>:LB` and `LB<:T<:UB`
#   Although syntactically it's possible to write `UB>:T` or `UB>:T>:LB`,
#   Julia doesn't accept such a syntax
extractLowerBound(expr) = begin
    hasLB = @capture(expr, T_ >: LB_)
    hasLB && return LB # if the first pattern worked, we are done
    hasLB = @capture(expr, LB_ <: T_ <: UB_)
    hasLB && return LB
    nothing # if neither pattern worked out
end

# Computes frequencies of lower bounds in `expr`
extractLowerBounds(expr) :: LBValsFreq = begin
    bounds = LBValsFreq()
    # we need to capture fresh state, so the local function
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
