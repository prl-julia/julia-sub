#!/usr/bin/env julia

#######################################################################
# Analysing Julia file for lower bounds
###############################
#
# The goal is to find all occurrences of lower bounds
#   on type variables in the text of a Julia program.
#
# This can happen in 2 cases:
#   1) where T >: Int
#   2) where Int <: T <: Number
#
# So first, we need to look for both `>:` and `<:` textually
#
# If at least one of those is present, parsing Julia code
#   can give more precise results.
#######################################################################

#--------------------------------------------------
# Imports
#--------------------------------------------------

include("src/JuliaSub.jl")

using Main.JuliaSub: PackageStat
using Main.JuliaSub: LBValsFreq, TxtConstrStat, LBStat, FileLBInfo, FilesLBInfo

#--------------------------------------------------
# Command line arguments
#--------------------------------------------------

if length(ARGS) != 1 || !isdir(ARGS[1])
    println("One argument—a folder with Julia packages—is expected")
    exit(1)
end

pkgsFolder = ARGS[1]

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Main
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#--------------------------------------------------
# Printing
#--------------------------------------------------

const SEP_BIG = "==================================================\n"
const SEP_SMALL = "------------------------------\n"
const LB_WIDTH = 8

showFreq(lbsFreq :: LBValsFreq, sep :: String = ",") = join(
    map(
        kv -> "$(rpad(kv[1], LB_WIDTH)) => $(kv[2])",
        sort(collect(pairs(lbsFreq.data)); by=kv->kv[2], rev=true)
    ),
    sep)

showTxtStat(txtStat :: TxtConstrStat) =
    "(<: $(txtStat.subConsr), >: $(txtStat.supConsr))"

showLBStat(::Nothing) = "∅"
showLBStat(stat :: LBStat, padFreq::String = "  ", sepFreq :: String = ", ") =
    "{ unique/lbs: $(stat.lbsUnique)/$(stat.lbs),\n" *
    padFreq * showFreq(stat.lbsFreq, sepFreq) * "\n}"

showFInfo(fileInfo :: FileLBInfo) =
    showTxtStat(fileInfo.txtStat) * "\n" * showLBStat(fileInfo.lbStat) * "\n"

showFsInfo(stats :: FilesLBInfo) = join(
    map(
        info -> "* $(rpad(info[1], LB_WIDTH)) => $(showFInfo(info[2]))",
        collect(pairs(stats))
    ),
    "\n")

#--------------------------------------------------
# Main analysis
#--------------------------------------------------

# For sorting packages based on their lower-bounds usage
interestFactor(pkgStat :: PackageStat) :: UInt =
    pkgStat.lbStat.lbsUnique*100 + pkgStat.lbStat.lbs

analyzeLBsAndOutputStats(pkgsPath :: String) = begin
    # analysis
    (badPkgs, goodPkgs, totalStat) = JuliaSub.processPkgsDir(pkgsPath)
    # sort packages information from most interesting to less interesting
    goodPkgs = sort(goodPkgs, by=interestFactor, rev=true)

    # failed packages
    if isempty(badPkgs)
        println("All packages processed successfully")
    else
        println("Failed packages (no src folder): $(length(badPkgs))")
        foreach(pkg -> println(pkg.name), badPkgs)
    end

    # output good packages
    println("\nGood packages: $(length(goodPkgs))")
    nonVacPkgsNum = 0
    for pkgInfo in goodPkgs
        pkgInfo.nonVacFilesNum == 0 && continue
        print(SEP_SMALL)
        nonVacPkgsNum += 1
        println("$(pkgInfo.name): " * showLBStat(pkgInfo.lbStat))
        println("Non vacuous files: $(pkgInfo.nonVacFilesNum)/$(pkgInfo.totalFilesNum)")
        println(showFsInfo(pkgInfo.filesInfo))
    end
    
    println(SEP_BIG)
    println("Interesting packages: $nonVacPkgsNum")
    println("Lower bounds: $(totalStat.lbs)")
    println("Unique lower bounds: $(totalStat.lbsUnique)")
    println(showFreq(totalStat.lbsFreq, "\n"))
    println()
end

analyzeLBsAndOutputStats(pkgsFolder)
