#######################################################################
# Utilities for using multisets in statistics
#######################################################################

# For Julia < 1.5 compatibility
const DICT_MERGE! = VERSION >= v"1.5" ? mergewith! : merge!

unionMergeWith!(ms :: Multiset, others :: Multiset...) = begin
    DICT_MERGE!(+, ms.data, map(ms -> ms.data, others)...)
    ms
end
