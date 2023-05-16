#######################################################################
# Processing package source code for type annotations and declarations
###############################
#
# Collection ana analysis of type annotations and declarations
#
#######################################################################

parseAndCollectTypeInfo(
    juliaFileName :: AbstractString
) :: TypeInfo = begin
    expr = parseJuliaFile(juliaFileName)
    TypeInfo(
        collectTypeAnnotations(expr),
        collectTypeDeclarations(expr)
    )
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Collecting type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const TYPE_ANNS_FNAME = "type-annotations.csv"
const TYPE_ANNS_ANALYSIS_FNAME = "analyzed-type-annotations.csv"
const TYPE_ANNS_SUMMARY_FNAME = "summary.csv"

const TYPE_DECLS_FNAME = "type-declarations.csv"

const INTR_TYPE_ANNS_FNAME = "interesting-type-annotations.csv"
const USESITE_TYPE_ANNS_FNAME = "non-use-site-type-annotations.csv"
const IMPUSESITE_TYPE_ANNS_FNAME = "non-imp-use-site-type-annotations.csv"

collectAndSaveTypeInfo2CSV(
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
        @status "Processing $pkgDir..."
        destPkgInfoPath = joinpath(destDirPath, pkgDir)
        isdir(destPkgInfoPath) || mkdir(destPkgInfoPath)
        pkgLog = collectAndSavePkgTypeInfo2CSV(pkgPath, destPkgInfoPath)
        @status "$pkgDir done"
        pkgDir => pkgLog
    end

    mapfunc = nprocs() > 1 ? pmap : map
    Dict(mapfunc(processPkg, pkgsWithPaths))
end

"""
ASSUMES: `destInfoDirPath` directory exists
"""
collectAndSavePkgTypeInfo2CSV(
    pkgPath :: AbstractString, destInfoDirPath :: AbstractString
) = begin
    # make sure pkgPath ends with "/" for consistency
    endswith(pkgPath, "/") ||
        (pkgPath *= "/")
    # handy for extracting paths within the package
    pkgPathLen1 = length(pkgPath) + 1
    filesLog = Dict(:succ => String[], :fail => String[])
    destFileIOAnns  = open(joinpath(destInfoDirPath, TYPE_ANNS_FNAME), "w")
    destFileIODecls = open(joinpath(destInfoDirPath, TYPE_DECLS_FNAME), "w")
    # recursively walk all Julia files in the package
    try 
        write(destFileIOAnns,  "File,Function,Kind,TypeAnnotation\n")
        write(destFileIODecls, "File,Kind,TypeDeclaration,Supertype\n")
        for (pkgSubDir, _, files) in walkdir(pkgPath)
            collectAndWritePkgDirTypeInfo2IO!(
                pkgPathLen1, pkgSubDir, files,
                destFileIOAnns, destFileIODecls, filesLog
            )
        end
    catch err
        @error "Problem when processing $pkgPath" err
    finally 
        close(destFileIOAnns)
        close(destFileIODecls)
    end
    filesLog
end

collectAndWritePkgDirTypeInfo2IO!(
    pkgPathLen1 :: Int, pkgSubdir :: AbstractString, files :: Vector,
    destFileIOAnns :: IOStream, destFileIODecls :: IOStream, 
    filesLog :: Dict{Symbol, Vector{String}}
) = begin
    for fileName in files
        filePath = joinpath(pkgSubdir, fileName)
        # process only Julia files
        isfile(filePath) && isJuliaFile(filePath) || continue
        try
            collectAndWritePkgFileTypeInfo2IO!(
                pkgPathLen1, filePath, destFileIOAnns, destFileIODecls)
            push!(filesLog[:succ], filePath)
        catch err
            @error "Problem when processing $filePath" err
            push!(filesLog[:fail], filePath)
        end
    end
end

collectAndWritePkgFileTypeInfo2IO!(
    pkgPathLen1 :: Int, jlFilePath :: AbstractString,
    destFileIOAnns :: IOStream, destFileIODecls :: IOStream
) = begin
    typeInfo = parseAndCollectTypeInfo(jlFilePath)
    jlFilePathInPkg = jlFilePath[pkgPathLen1:end]
    for tyAnn in reverse(typeInfo.tyAnns)
        printFieldsToCSV!(
            [jlFilePathInPkg, tyAnn.funName, tyAnn.kind, tyAnn.tyExpr],
            destFileIOAnns
        )
    end
    for tyDecl in reverse(typeInfo.tyDecls)
        printFieldsToCSV!(
            [jlFilePathInPkg, tyDecl.kind, tyDecl.tyDecl, tyDecl.tySuper],
            destFileIODecls
        )
    end
end

"""
ASSUMES: `fields` is not empty
"""
printFieldsToCSV!(fields :: Vector, destFileIO :: IOStream) = begin
    for info in fields[begin:end-1] 
        show(destFileIO, string(info))
        write(destFileIO, ",")
    end
    show(destFileIO, string(fields[end]))
    write(destFileIO, "\n")
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"Should coincide with the new columns in `addTypeAnnsAnalysis!`"
const ANALYSIS_COLS = [
    :Error, :Warning,
    :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance,
    :ImprUseSiteVariance, :RestrictedScope, :ClosedLowerBound
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
        @status "Processing $pkgDir..."
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
        for key in [:pkgwarn, :pkgusesite, :pkgintr, :tasintr, :tasusvar, :tasiusvar]
            d[key] = vcat(d1[key], d2[key])
        end
        d
    end
    rslt = reduce(combineResults, pkgResults)

    try 
        CSV.write(joinpath(pkgsDirPath, INTR_TYPE_ANNS_FNAME), rslt[:tasintr])
        CSV.write(joinpath(pkgsDirPath, USESITE_TYPE_ANNS_FNAME), rslt[:tasusvar])
        CSV.write(joinpath(pkgsDirPath, IMPUSESITE_TYPE_ANNS_FNAME), rslt[:tasiusvar])
    catch err
        @error "Problem when saving interesting type annotations" err
    end
    rslt
end

analyzePkgTypeAnns(pkgPath :: AbstractString) = begin
    failedResult = Dict(
        :goodPkg        => 0, 
        :badPkg         => 1,
        :totalta        => 0,
        :statnames      => ANALYSIS_COLS,
        :statsums       => fill(0, length(ANALYSIS_COLS)),
        :pkgwarn        => [],
        :pkgusesite     => [],
        :pkgintr        => [],
        :tasintr        => DataFrame(),
        :tasusvar       => DataFrame(),
        :tasiusvar      => DataFrame(),
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
        df = CSV.read(typeAnnsPath, DataFrame; escapechar='\\')
        df = addTypeAnnsAnalysis!(df)
        dfSumm = summarizeTypeAnnsAnalysis(df)
        CSV.write(
            joinpath(pkgPath, TYPE_ANNS_ANALYSIS_FNAME),
            #df[:, [:File, :Function, :Kind, :TypeAnnotation, :Error, :Warning, :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance, :RestrictedScope]]
            df[:, Not("TypeVarsSummary")]
        )
        CSV.write(joinpath(pkgPath, TYPE_ANNS_SUMMARY_FNAME), dfSumm)
        errOrWarn = dfSumm.sum[1] > 0 || dfSumm.sum[2] > 0
        totalta = size(df, 1)
        strongRestrictionFailed = any(
            ind -> dfSumm.sum[ind] < totalta,
            [7, 8, 9]
        )
        dfta  = df[.!(ismissing.(df.ImprUseSiteVariance)) .&& 
            (.!df.ImprUseSiteVariance .|| .!df.RestrictedScope .|| .!df.ClosedLowerBound), :]
        dfus  = df[.!(ismissing.(df.UseSiteVariance)) .&& .!df.UseSiteVariance, :]
        dfius = df[.!(ismissing.(df.ImprUseSiteVariance)) .&& .!df.ImprUseSiteVariance, :]
        dfta.Package  = fill(pkgPath, size(dfta,  1))      
        dfus.Package  = fill(pkgPath, size(dfus,  1))
        dfius.Package = fill(pkgPath, size(dfius, 1))
        Dict(
            :goodPkg    => 1, 
            :badPkg     => 0,
            :totalta    => totalta,
            :statnames  => dfSumm.variable,
            :statsums   => dfSumm.sum,
            :pkgwarn    => errOrWarn ? [pkgPath] : [],
            :pkgusesite => dfSumm.sum[6] < totalta ? [pkgPath] : [],
            :pkgintr    => strongRestrictionFailed ? [pkgPath] : [],
            :tasintr    => dfta,
            :tasusvar   => dfus,
            :tasiusvar   => dfius,
        )
    catch err
        @error "Problem when processing CSVs" err
        failedResult
    end
end

addTypeAnnsAnalysis!(df :: DataFrame) = begin
    df.UnrolledTypeAnnotation = ByRow(tastr -> 
        try
            string(transformShortHand(Meta.parse(tastr)).expr)
        catch err
            @error "Couldn't transform type annotation" tastr err
            missing
        end
    )(df.TypeAnnotation)
    df.TypeVarsSummary = ByRow(tastr -> (ismissing(tastr) ? missing :
        try
            collectTyVarsSummary(Meta.parse(tastr))
        catch err
            @error "Couldn't analyze type annotation" tastr err
            missing
        end)
    )(df.UnrolledTypeAnnotation)
    df.Error = ByRow(ismissing)(df.TypeVarsSummary)
    df.Warning = ByRow(
        tasumm -> ismissing(tasumm) ? true : tasumm[2]
    )(df.TypeVarsSummary) 
    df.VarCnt = mkDFAnalysisFunction(length, df.TypeVarsSummary)
    df.HasWhere = ByRow(
        varcnt -> ismissing(varcnt) ? missing : varcnt > 0
    )(df.VarCnt)
    for (col, fun) in [
       :VarsUsedOnce        => tyVarUsedOnce,
       :UseSiteVariance     => tyVarOccursAsUsedSiteVariance,
       :ImprUseSiteVariance => tyVarOccursAsImpredicativeUsedSiteVariance,
       :RestrictedScope     => tyVarRestrictedScopePreserved,
       :ClosedLowerBound    => tyVarIsNotInLowerBound,
    ]
        df[!, col] = mkDFAnalysisFunction(fun, df.TypeVarsSummary)
    end
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
    cols = ANALYSIS_COLS
)
