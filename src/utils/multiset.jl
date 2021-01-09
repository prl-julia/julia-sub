#######################################################################
# Utilities for using multisets
#######################################################################

# For Julia < 1.5 compatibility
const DICT_MERGE! = VERSION >= v"1.5" ? mergewith! : merge!

# Multiset → Int
# Returns the number of unique values in `ms`
lengthUnique(ms :: Multiset) = length(ms.data)

# (Multiset, Multiset...) → Multiset
# SIDE EFFECT: modifies `ms`
# Adds up all data from `others` to `ms`
# For example, ("a":2, "b":1) with ("c":2, "b":2) is ("a":2, "b":3, "c":2)
unionMergeWith!(ms :: Multiset, others :: Multiset...) = begin
    DICT_MERGE!(+, ms.data, map(ms -> ms.data, others)...)
    ms
end
