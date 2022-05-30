#######################################################################
# Processing package source code for type annotations
###############################
#
# TODO
#
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Collecting type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const TYPE_ANNS_FNAME = "type-annotations.csv"
const TYPE_ANNS_ANALYSIS_FNAME = "analyzed-type-annotations.csv"
const TYPE_ANNS_SUMMARY_FNAME = "summary.csv"

collectAndSaveTypeAnns2CSV(
    pkgsDirPath :: AbstractString, destDirPath :: AbstractString
) = begin
    if !isdir(pkgsDirPath)
        @error "Packages directory doesn't exist: $pkgsDirPath"
        return nothing
    end
    isdir(destDirPath) || mkdir(destDirPath)

    pkgsWithPaths = map(
            pkgDir -> (pkgDir, joinpath(pkgsDirPath, pkgDir)),
            readdir(pkgsDirPath)
        )
    pkgsWithPaths = filter(pkg -> isdir(pkg[2]), pkgsWithPaths)

    processPkg((pkgDir, pkgPath)) = begin
        @info "Processing $pkgDir..."
        destPkgInfoPath = joinpath(destDirPath, pkgDir)
        isdir(destPkgInfoPath) || mkdir(destPkgInfoPath)
        tyAnnFilePath = joinpath(destPkgInfoPath, TYPE_ANNS_FNAME)
        pkgLog = collectAndSavePkgTypeAnns2CSV(pkgPath, tyAnnFilePath)
        @info "$pkgDir done"
        pkgDir => pkgLog
    end

    mapfunc = nprocs() > 1 ? pmap : map
    Dict(mapfunc(processPkg, pkgsWithPaths))
end

collectAndSavePkgTypeAnns2CSV(
    pkgPath :: AbstractString, destFilePath :: AbstractString
) = begin
    # make sure pkgPath ends with "/" for consistency
    endswith(pkgPath, "/") ||
        (pkgPath *= "/")
    # handy for extracting paths within the package
    pkgPathLen1 = length(pkgPath) + 1
    filesLog = Dict(:succ => String[], :fail => String[])
    destFileIO = open(destFilePath, "w")
    # recursively walk all Julia files in the package
    try 
        write(destFileIO, "File,Function,Kind,TypeAnnotation\n")
        for (pkgSubDir, _, files) in walkdir(pkgPath)
            collectAndWritePkgDirTypeAnns2IO!(
                pkgPathLen1, pkgSubDir, files,
                destFileIO, filesLog
            )
        end
    catch err
        @error "Problem when processing $pkgPath" err
    finally 
        close(destFileIO)
    end
    filesLog
end

collectAndWritePkgDirTypeAnns2IO!(
    pkgPathLen1 :: Int, pkgSubdir :: AbstractString, files :: Vector,
    destFileIO :: IOStream, filesLog :: Dict{Symbol, Vector{String}}
) = begin
    for fileName in files
        filePath = joinpath(pkgSubdir, fileName)
        # process only Julia files
        isfile(filePath) && isJuliaFile(filePath) || continue
        try
            collectAndWritePkgFileTypeAnns2IO!(pkgPathLen1, filePath, destFileIO)
            push!(filesLog[:succ], filePath)
        catch err
            @error "Problem when processing $filePath" err
            push!(filesLog[:fail], filePath)
        end
    end
end

collectAndWritePkgFileTypeAnns2IO!(
    pkgPathLen1 :: Int, jlFilePath :: AbstractString,
    destFileIO :: IOStream
) = begin
    reversedTypeAnns = parseAndCollectTypeAnnotations(jlFilePath)
    jlFilePathInPkg = jlFilePath[pkgPathLen1:end]
    for tyAnn in reverse(reversedTypeAnns)
        #=write(
            destFileIO,
            jlFilePathInPkg * "," * csvLineString(tyAnn)
        )=#
        show(destFileIO, jlFilePathInPkg)
        write(destFileIO, ",")
        show(destFileIO, string(tyAnn.funName))
        write(destFileIO, ",")
        show(destFileIO, string(tyAnn.kind))
        write(destFileIO, ",")
        show(destFileIO, string(tyAnn.tyExpr))
        write(destFileIO, "\n")
    end
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

analyzePkgTypeAnnsAndSave2CSV(
    pkgsDirPath :: AbstractString
) = begin
    if !isdir(pkgsDirPath)
        @error "Packages directory doesn't exist: $pkgsDirPath"
        return nothing
    end

    pkgsWithPaths = map(
            pkgDir -> (pkgDir, joinpath(pkgsDirPath, pkgDir)),
            readdir(pkgsDirPath)
        )
    pkgsWithPaths = filter(pkg -> isdir(pkg[2]), pkgsWithPaths)

    (goodPkgs, badPkgs, totalTyAnns, allSums) = (0, 0, 0, [0,0,0,0])

    processPkg((pkgDir, pkgPath)) = begin
        @info "Processing $pkgDir..."
        analyzePkgTypeAnns(pkgPath)
    end

    mapfunc = nprocs() > 1 ? pmap : map
    for (good, bad, total, sums) in mapfunc(processPkg, pkgsWithPaths)
        goodPkgs += good
        badPkgs += bad
        totalTyAnns += total
        allSums += sums
    end
    (goodPkgs, badPkgs, totalTyAnns, allSums)
end

analyzePkgTypeAnns(pkgPath :: AbstractString) = begin
    if !isdir(pkgPath)
        @error "Packages directory doesn't exist: $pkgsDirPath"
        return (0, 1, 0, [0,0,0,0])
    end
    typeAnnsPath = joinpath(pkgPath, TYPE_ANNS_FNAME)
    if !isfile(typeAnnsPath)
        @error "Type annotations file doesn't exist: $typeAnnsPath"
        return (0, 1, 0, [0,0,0,0])
    end
    try
        df = load(typeAnnsPath; escapechar='\\') |> DataFrame #CSV.read(typeAnnsPath, DataFrame)
        df = addTypeAnnsAnalysis!(df)
        dfSumm = summarizeTypeAnns(df)
        CSV.write(
            joinpath(pkgPath, TYPE_ANNS_ANALYSIS_FNAME),
            df[:, [:File, :Function, :Kind, :TypeAnnotation, :VarCnt, :VarsUsedOnce, :UseSiteVariance, :RestrictedScope]]
        )
        CSV.write(joinpath(pkgPath, TYPE_ANNS_SUMMARY_FNAME), dfSumm)
        (1, 0, size(df)[1], dfSumm.sum)
    catch err
        @error "Problem when processing CSVs" err
        (0, 1, 0, [0,0,0,0])
    end
end

addTypeAnnsAnalysis!(df :: DataFrame) = begin
    df.TypeVarsSummary = ByRow(
        tastr -> 
        try
            collectTyVarsSummary(Meta.parse(tastr))
        catch err
            @error "Couldn't process type annotation" tastr err
            TypeTyVarsSummary() #missing
        end
    )(df.TypeAnnotation)
    df.VarCnt = ByRow(length)(df.TypeVarsSummary)
    df.VarsUsedOnce = mkDFAnalysisFunction(tyVarUsedOnce, df.TypeVarsSummary)
    df.UseSiteVariance = mkDFAnalysisFunction(tyVarOccursAsUsedSiteVariance, df.TypeVarsSummary)
    df.RestrictedScope = mkDFAnalysisFunction(tyVarRestrictedScopePreserved, df.TypeVarsSummary)
    df
end

mkDFAnalysisFunction(fun :: Function, dfrow) = ByRow(summ ->
    try
        fun(summ)
    catch err
        @error "Couldn't analyze $(Symbol(fun)) for type vars summary" summ err
        missing
    end
)(dfrow)

summarizeTypeAnns(df :: DataFrame) = describe(df, 
    :mean, :min, :median, :max,
    :nmissing,
    sum => :sum,
    cols=[:VarCnt, :VarsUsedOnce, :UseSiteVariance, :RestrictedScope]
)

Base.length(::Missing) = missing
tyVarUsedOnce(::Missing) = missing
tyVarOccursAsUsedSiteVariance(::Missing) = missing
tyVarRestrictedScopePreserved(::Missing) = missing
