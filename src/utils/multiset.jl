#######################################################################
# Utilities for using multisets in statistics
#######################################################################

Base.mergewith!(ms1 :: Multiset, ms2 :: Multiset) = begin
    mergewith!(+, ms1.data, ms2.data)
    ms1
end
