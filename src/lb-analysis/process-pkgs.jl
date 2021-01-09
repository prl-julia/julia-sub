#######################################################################
# Analysing Julia files and packages for lower bounds
###############################
#
# Functions for gathering lower-bound statistics
# for individual files, packages, and lists of packages
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysis of files
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Checks if `filePath` is a Julia file
isJuliaFile(filePath :: String) :: Bool = endswith(filePath, ".jl")

# Assuming that `pkgPath` is a prefix of `filePath`,
# carves out the path to the file within ``pkgPath``
filePathWithinPkg(filePath::String, pkgPath::String) :: String =
    filePath[length(pkgPath)+2:end]

# Reads file `filePath` located in `pkgPath`
# and updates `pkgStat` accordingly with the file's lower-bounds stats
# - keeps track of failed and interesting files
processFile(filePath::String, pkgPath::String, pkgStat::PackageStat) = begin
    fileInfo = nothing
    try
        # file might not be accessible
        fileInfo = lbFileInfo(filePath; isPath=true)
    catch e
        isa(e, Base.IOError) ? @debugonly(@warn e) : @error e
    end
    if fileInfo === nothing || fileInfo.err !== nothing
        pkgStat.failedFiles += 1
    elseif nonVacuous(fileInfo.lbStat)
        pkgStat.interestingFiles += 1
        # cut pkgPath from file name for readability
        pkgStat.filesInfo[filePathWithinPkg(filePath, pkgPath)] = fileInfo
    end
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysis of a package
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Walks `files` in `root`
# and adds their lower-bounds statistics to `pkgStat`
processFilesInDir(root, files, pkgsPath::String, pkgStat::PackageStat) = begin
    # we are only interested in Julia files
    files = filter(isJuliaFile, files)
    pkgStat.totalFiles += length(files)
    map(file -> processFile(joinpath(root, file), pkgsPath, pkgStat),
        files)
end

# Adds up all lower-bounds statistics from `filesInfo`
accumulateLBStat(filesInfo :: FilesLBInfo) :: LBStat = begin
    bounds = LBValsFreq()
    for fInfo in values(filesInfo)
        fInfo.lbStat === nothing ||
            unionMergeWith!(bounds, fInfo.lbStat.lbsFreq)
    end
    LBStat(bounds)
end

# Walks `src` directory of package `pkgName` located at `pkgsPath`
# and collects lower-bounds statistics
processPkg(pkgsPath :: String, pkgName :: String) :: PackageStat = begin
    srcPath = joinpath(pkgsPath, "src")
    # we assume that correct Julia packages have `src` folder,
    # otherwise we are not interested
    pkgStat = PackageStat(pkgName, isdir(srcPath))
    pkgStat.hasSrc || return pkgStat
    # recursively walk all files in [src]
    for (root, _, files) in walkdir(srcPath)
        processFilesInDir(root, files, pkgsPath, pkgStat)
    end
    # package summary statistics
    if pkgStat.interestingFiles > 0
        pkgStat.pkgLBStat = accumulateLBStat(pkgStat.filesInfo)
    end
    pkgStat
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysis of packages
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

isGoodPackage(pkgStat :: PackageStat) :: Bool = pkgStat.hasSrc

interestFactor(pkgStat :: PackageStat) =
    pkgStat.pkgLBStat.lbsUnique*100 + pkgStat.pkgLBStat.lbs

# String → (Vector{PackageStat}, Vector{PackageStat}, LBStat)
# Processes every folder in `pkgsPath` as a package folder
# and computes lower-bounds statistics for it.
# Returns failed packages and stats for successfully processed packages
function processPkgsDir(pkgsPath :: String)
    paths = map(name -> (joinpath(pkgsPath, name), name), readdir(pkgsPath))
    dirs  = filter(d -> isdir(d[1]), paths)

    pkgsNum = length(dirs)
    println("Packages to process: $pkgsNum")
    pkgsStats = PackageStat[]
    if VERBOSE
        pkgsStats = Vector{PackageStat}(undef, pkgsNum)
        for pkgi in 1:pkgsNum
            pkgsStats[pkgi] = processPkg(dirs[pkgi][1], dirs[pkgi][2])
            if pkgi % PKGS_NUM_STEP == 0
                @info "$pkgi packages processed"
            end
        end
    else
        pkgsStats = map(d -> processPkg(d[1], d[2]), dirs)
    end

    # sort packages information from most interesting to less interesting
    goodPkgs  = sort(
        filter(isGoodPackage,  pkgsStats),
        by=interestFactor, rev=true)
    badPkgs   = filter(!isGoodPackage, pkgsStats)
    # gather cumulative statistics
    totalLBFreq = LBValsFreq()
    foreach(pkgStat -> unionMergeWith!(totalLBFreq, pkgStat.pkgLBStat.lbsFreq),
            goodPkgs)
    (badPkgs, goodPkgs, LBStat(totalLBFreq))
end