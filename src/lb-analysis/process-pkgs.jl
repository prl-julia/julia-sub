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
        pkgStat.failedFilesNum += 1
    elseif nonVacuous(fileInfo.lbStat)
        pkgStat.nonVacFilesNum += 1
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
    pkgStat.totalFilesNum += length(files)
    map(file -> processFile(joinpath(root, file), pkgsPath, pkgStat),
        files)
end

# Returns cumulative lower-bound statistics
# for all files in `filesInfo`
cumulativeLBStat(filesInfo :: FilesLBInfo) :: LBStat = begin
    totalLBFreq = LBValsFreq()
    for fInfo in values(filesInfo)
        fInfo.lbStat === nothing ||
            unionMergeWith!(totalLBFreq, fInfo.lbStat.lbsFreq)
    end
    LBStat(totalLBFreq)
end

# Walks `src` directory of package `pkgName` located at `pkgPath`
# and collects its lower-bounds statistics
processPkg(pkgPath :: String, pkgName :: String) :: PackageStat = begin
    srcPath = joinpath(pkgPath, "src")
    # we assume that correct Julia packages have `src` folder,
    # otherwise we are not interested
    pkgStat = PackageStat(pkgName, isdir(srcPath))
    pkgStat.hasSrc || return pkgStat
    # recursively walk all files in [src]
    for (root, _, files) in walkdir(srcPath)
        processFilesInDir(root, files, pkgPath, pkgStat)
    end
    # package summary statistics
    if pkgStat.nonVacFilesNum > 0
        pkgStat.lbStat = cumulativeLBStat(pkgStat.filesInfo)
    end
    pkgStat
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysis of packages
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pkgHasSrc(pkgStat :: PackageStat) :: Bool = pkgStat.hasSrc

# Returns cumulative lower-bound statistics
# for all packages in `pkgsStat`
cumulativeLBStat(pkgsStat :: Vector{PackageStat}) :: LBStat = begin
    totalLBFreq = LBValsFreq()
    for pkgStat in pkgsStat
        unionMergeWith!(totalLBFreq, pkgStat.lbStat.lbsFreq)
    end
    LBStat(totalLBFreq)
end

# String → (Vector{PackageStat}, Vector{PackageStat}, LBStat)
# Processes every folder in `pkgsPath` as a package folder
#   and computes lower-bounds statistics for it.
# Returns failed packages, successfully processed packages with their stats,
#   and cumulative statstics of good packages.
processPkgsDir(pkgsPath :: String) = begin
    pathsAndNames = subdirPathsWithNames(pkgsPath)
    processPkgPathAndName(pn) = begin
        @statusb "Processing package $(pn[2])"
        processPkg(pn[1], pn[2])
    end

    pkgsNum = length(pathsAndNames)
    pkgsStats = PackageStat[]
    if VERBOSE
        pkgsStats = Vector{PackageStat}(undef, pkgsNum)
        for pkgi in 1:pkgsNum
            pkgsStats[pkgi] = processPkgPathAndName(pathsAndNames[pkgi])
            pkgi % PKGS_NUM_STEP == 0 && @info "$pkgi PKGS PROCESSED"
        end
    else
        pkgsStats = map(processPkgPathAndName, pathsAndNames)
    end

    # sort packages information from most interesting to less interesting
    goodPkgs = filter(pkgHasSrc, pkgsStats)
    badPkgs  = filter(!pkgHasSrc, pkgsStats)
    (badPkgs, goodPkgs, cumulativeLBStat(goodPkgs))
end