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

#--------------------------------------------------
# Command line arguments
#--------------------------------------------------

if length(ARGS) != 1 || !isdir(ARGS[1])
    println("One argument—a folder with Julia packages—is expected")
    exit(1)
end

pkgsFolder = ARGS[1]

#--------------------------------------------------
# Main
#--------------------------------------------------

const SEP_BIG = "==================================================\n"
const SEP_SMALL = "------------------------------\n"

processPkgsAndPrintLBStat(pkgsPath :: String) = begin
    (badPkgs, goodPkgs, totalStat) = JuliaSub.processPkgsDir(pkgsPath)
    if length(badPkgs) > 0
        println("Failed packages (no src folder): $(length(badPkgs))")
        foreach(pkg -> println(pkg.pkgName), badPkgs)
    else
        println("All packages processed successfully")
    end

    println()
    println("Good packages: $(length(goodPkgs))")
    interestingPkgs = 0
    for pkgInfo in goodPkgs
        if pkgInfo.interestingFiles == 0
            continue
        end
        print(SEP_SMALL)
        interestingPkgs += 1
        println("$(pkgInfo.pkgName): $(pkgInfo.pkgLBStat)")
        println("# non vacuous files: $(pkgInfo.interestingFiles)/$(pkgInfo.totalFiles)")
        print(pkgInfo.filesInfo)
    end
    
    println(SEP_BIG)
    println("Interesting packages: $interestingPkgs")
    println("Lower bounds: $(totalStat.lbs)")
    println("Unique lower bounds: $(totalStat.lbsUnique)")
    Base.show(stdout, totalStat.lbsFreq, "\n")
    println()
end

processPkgsAndPrintLBStat(pkgsFolder)