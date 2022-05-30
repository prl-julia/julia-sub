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

"Should coincide with the new columns in `addTypeAnnsAnalysis!`"
const ANALYSIS_COLS = [
    :Error, :Warning,
    :VarCnt, :HasWhere, :VarsUsedOnce,
    :UseSiteVariance, :RestrictedScope
]

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

    processPkg((pkgDir, pkgPath)) = begin
        @info "Processing $pkgDir..."
        analyzePkgTypeAnns(pkgPath)
    end
    mapfunc = nprocs() > 1 ? pmap : map
    pkgResults = mapfunc(processPkg, pkgsWithPaths)

    combineResults(d1, d2) = begin
        d = Dict{Symbol, Any}()
        for key in [:goodPkg, :badPkg, :totalta, :statsums]
            d[key] = d1[key] + d2[key]
        end
        d[:statnames] = d1[:statnames]
        d
    end
    reduce(combineResults, pkgResults)
end

analyzePkgTypeAnns(pkgPath :: AbstractString) = begin
    failedResult = Dict(
        :goodPkg    => 0, 
        :badPkg     => 1,
        :totalta    => 0,
        :statnames  => ANALYSIS_COLS,
        :statsums   => fill(0, length(ANALYSIS_COLS))
    )
    if !isdir(pkgPath)
        @error "Packages directory doesn't exist: $pkgPath"
        return failedResult
    end
    typeAnnsPath = joinpath(pkgPath, TYPE_ANNS_FNAME)
    if !isfile(typeAnnsPath)
        @error "Type annotations file doesn't exist: $typeAnnsPath"
        return failedResult
    end
    try
        #CSV.read(typeAnnsPath, DataFrame) # fails to properly recognize \" in strings
        df = load(typeAnnsPath; escapechar='\\') |> DataFrame
        df = addTypeAnnsAnalysis!(df)
        dfSumm = summarizeTypeAnnsAnalysis(df)
        CSV.write(
            joinpath(pkgPath, TYPE_ANNS_ANALYSIS_FNAME),
            #df[:, [:File, :Function, :Kind, :TypeAnnotation, :Error, :Warning, :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance, :RestrictedScope]]
            df[:, Not("TypeVarsSummary")]
        )
        CSV.write(joinpath(pkgPath, TYPE_ANNS_SUMMARY_FNAME), dfSumm)
        Dict(
            :goodPkg    => 1, 
            :badPkg     => 0,
            :totalta    => size(df, 1),
            :statnames  => dfSumm.variable,
            :statsums   => dfSumm.sum
        )
    catch err
        @error "Problem when processing CSVs" err
        failedResult
    end
end

addTypeAnnsAnalysis!(df :: DataFrame) = begin
    df.TypeVarsSummary = ByRow(
        tastr -> 
        try
            collectTyVarsSummary(Meta.parse(tastr))
        catch err
            @error "Couldn't process type annotation" tastr err
            #TypeTyVarsSummary() #missing
            missing
        end
    )(df.TypeAnnotation)
    df.Error = ByRow(ismissing)(df.TypeVarsSummary)
    df.Warning = ByRow(
        tasumm ->
        ismissing(tasumm) ? true : tasumm[2]
    )(df.TypeVarsSummary) 
    df.VarCnt = mkDFAnalysisFunction(length, df.TypeVarsSummary)
    df.HasWhere = ByRow(
        varcnt -> ismissing(varcnt) ? missing : varcnt > 0
    )(df.VarCnt)
    df.VarsUsedOnce = mkDFAnalysisFunction(tyVarUsedOnce, df.TypeVarsSummary)
    df.UseSiteVariance = mkDFAnalysisFunction(tyVarOccursAsUsedSiteVariance, df.TypeVarsSummary)
    df.RestrictedScope = mkDFAnalysisFunction(tyVarRestrictedScopePreserved, df.TypeVarsSummary)
    df
end

mkDFAnalysisFunction(fun :: Function, dfrow) = ByRow(tasumm ->
    ismissing(tasumm) ? 
    missing :
    try
        fun(tasumm[1])
    catch err
        @error "Couldn't analyze $(Symbol(fun)) for type vars summary" tasumm[1] err
        missing
    end
)(dfrow)

summarizeTypeAnnsAnalysis(df :: DataFrame) = describe(df, 
    :mean, :min, :median, :max,
    :nmissing,
    sum => :sum,
    cols=[:Error, :Warning, :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance, :RestrictedScope]
)
