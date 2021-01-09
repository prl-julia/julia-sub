#######################################################################
# Data types for the analysis of lower bounds
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysis
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Simple search of text for `<:` and `>:`
#--------------------------------------------------

@enum ConstrKind subtc suptc

# Regex expressions corresponding to
# subtype and supertype constraints
const CONSTRAINT_PATTERN = Dict(
    subtc => "<:",
    suptc => ">:"
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Gathering statistics
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Cumulative lower-bounds stat
#--------------------------------------------------

# Information about textual and parsing-based
# appearance of lower-bound constraints
struct TxtConstrStat
    subConsr :: UInt     # number of `<:` in text
    supConsr :: UInt     # number of `>:` in text
end
TxtConstrStat() = TxtConstrStat(0, 0)

# Frequencies of lower-bound values
LBValsFreq = Multiset

# Information about lower-bound constraints
struct LBStat
    lbs         :: UInt     # number of lower bounds
    lbsUnique   :: UInt     # number of unique lower-bound values
    lbsFreq     :: LBValsFreq   # frequencies of lower-bound values
end
LBStat() = LBStat(0, 0, LBValsFreq())
LBStat(lbsFreq :: LBValsFreq) =
    LBStat(length(lbsFreq), lengthUnique(lbsFreq), lbsFreq)

#--------------------------------------------------
# File stat
#--------------------------------------------------

# Information about lower bounds in a file:
# - `txtStat`   textual bounds info
# - `err`       possibly exception during processing
# - `lbStat`    possibly proper lb-stat if `txtStat` is non-vacuous
struct LBFileInfo
    txtStat :: TxtConstrStat
    err     :: Union{Exception, Nothing}
    lbStat  :: Union{LBStat, Nothing}
end
LBFileInfo(txtStat :: TxtConstrStat) =
    LBFileInfo(txtStat, nothing, nothing)
LBFileInfo(txtStat :: TxtConstrStat, err :: Exception) =
    LBFileInfo(txtStat, err, nothing)
LBFileInfo(txtStat :: TxtConstrStat, lbStat :: LBStat) =
    LBFileInfo(txtStat, nothing, lbStat)

#--------------------------------------------------
# Package stat
#--------------------------------------------------

# Files statistics (fileName => statistics)
FilesLBInfo = Dict{String, LBFileInfo}

# Single package statistics
mutable struct PackageStat
    pkgName          :: String
    hasSrc           :: Bool
    totalFiles       :: UInt # number of source Julia files
    failedFiles      :: UInt # number of files that failed to process
    interestingFiles :: UInt # number of files with lower bounds
    filesInfo        :: FilesLBInfo # fileName => LBFileInfo
    pkgLBStat        :: LBStat # package cumulative statistics
end
PackageStat(pkgName :: String, hasSrc :: Bool) = 
    PackageStat(pkgName, hasSrc, 0, 0, 0, FilesLBInfo(), LBStat())

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Base functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Equality
#--------------------------------------------------

Base.:(==)(v1 :: TxtConstrStat, v2 :: TxtConstrStat) = structEqual(v1, v2)

Base.:(==)(v1 :: LBStat, v2 :: LBStat) = structEqual(v1, v2)

Base.:(==)(v1 :: LBFileInfo, v2 :: LBFileInfo) = structEqual(v1, v2)

Base.:(==)(v1 :: PackageStat, v2 :: PackageStat) = structEqual(v1, v2)

#--------------------------------------------------
# Show
#--------------------------------------------------

Base.show(io :: IO, un :: UInt) = print(io, string(un, base=10))

Base.show(io :: IO, txtStat :: TxtConstrStat) = print(io,
    "{<: $(txtStat.subConsr), >: $(txtStat.supConsr)}")

Base.show(io :: IO, lbsFreq :: LBValsFreq, sep :: String = ", ") = print(io, 
    join(map(kv -> "$(kv[1]) => $(kv[2])",
            sort(collect(pairs(lbsFreq.data)); by=kv->kv[2], rev=true)),
         sep))

Base.show(io :: IO, stat :: LBStat, sep :: String = ", ") = begin
    print(io,
        " lbs: $(stat.lbs), unique: $(stat.lbsUnique),\n" *
        "  lbsFreq: ")
    Base.show(io, stat.lbsFreq, sep)
end

Base.show(io :: IO, fileInfo :: LBFileInfo) = print(io,
    "$(fileInfo.txtStat)\n" *
    " $(fileInfo.lbStat)\n")

Base.show(io :: IO, stat :: FilesLBInfo) = begin
    for info in stat
        println(io, "* $(info[1]) => $(info[2])")
    end
end