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
# So we need to look for both `>:` and `<:`
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Simple search of text for `<:` and `>:`
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Returns the number of occurences of constraint `constr` in `text`
countTextualConstr(constr :: ConstrKind, text :: String) =
    count(CONSTRAINT_REGEX[constr], text)
