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
const TYPE_ANNS_SUMMARY_FNAME = "summary-type-annotations.csv"

const TYPE_DECLS_FNAME = "type-declarations.csv"
const TYPE_DECLS_ANALYSIS_FNAME = "analyzed-type-declarations.csv"
const TYPE_DECLS_SUMMARY_FNAME = "summary-type-declarations.csv"

const INTR_TYPE_ANNS_FNAME = "interesting-type-annotations.csv"
const USESITE_TYPE_ANNS_FNAME = "non-use-site-type-annotations.csv"
const IMPUSESITE_TYPE_ANNS_FNAME = "non-imp-use-site-type-annotations.csv"

const USESITE_TYPE_DECLS_FNAME = "non-use-site-type-declarations.csv"

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
        write(destFileIODecls, "File,Name,Kind,TypeDeclaration,Supertype\n")
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
            [jlFilePathInPkg, tyDecl.name, tyDecl.kind, tyDecl.tyDecl, tyDecl.tySuper],
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
# Analysing type information
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

analyzePkgTypesAndSave2CSV(
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
        (analyzePkgTypeAnns(pkgPath), analyzePkgTypeDecls(pkgPath))
    end
    mapfunc = nprocs() > 1 ? pmap : map
    pkgResults = mapfunc(processPkg, pkgsWithPaths)

    combineSum!(dr, d1, d2, keys) =
        for key in keys
            dr[key] = d1[key] + d2[key]
        end
    combineVCat!(dr, d1, d2, keys) =
        for key in keys
            dr[key] = vcat(d1[key], d2[key])
        end
    combineResults((dta1, dtd1), (dta2, dtd2)) = begin
        (dta, dtd) = (Dict{Symbol, Any}(), Dict{Symbol, Any}())
        combineSum!(dta, dta1, dta2, [:goodPkg, :badPkg, :totalta, :statsums])
        combineSum!(dtd, dtd1, dtd2, [:goodPkg, :badPkg, :totaltd, :statsums])
        dta[:statnames] = dta1[:statnames]
        dtd[:statnames] = dtd1[:statnames]
        combineVCat!(dta, dta1, dta2, 
            [:pkgwarn, :pkgusesite, :pkgintr, :tasintr, :tasusvar, :tasiusvar])
        combineVCat!(dtd, dtd1, dtd2, [:pkgwarn, :pkgusesite, :tdsusvar])
        (dta, dtd)
    end
    (rsltta, rslttd) = reduce(combineResults, pkgResults)

    try 
        CSV.write(joinpath(pkgsDirPath, INTR_TYPE_ANNS_FNAME), rsltta[:tasintr])
        CSV.write(joinpath(pkgsDirPath, USESITE_TYPE_ANNS_FNAME), rsltta[:tasusvar])
        CSV.write(joinpath(pkgsDirPath, IMPUSESITE_TYPE_ANNS_FNAME), rsltta[:tasiusvar])
        CSV.write(joinpath(pkgsDirPath, USESITE_TYPE_DECLS_FNAME), rslttd[:tdsusvar])
    catch err
        @error "Problem when saving interesting type info" err
    end
    (rsltta, rslttd)
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const ANALYSIS_COLS_ANNS_NOERR = [
    :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance,
    :ImprUseSiteVariance, :RestrictedScope, :ClosedLowerBound
]

"Should coincide with the new columns added in `addTypeAnnsAnalysis!`"
const ANALYSIS_COLS_ANNS = vcat(
    [:Error, :Warning],
    ANALYSIS_COLS_ANNS_NOERR
)

analyzePkgTypeAnns(pkgPath :: AbstractString) :: Dict = begin
    failedResult = Dict(
        :goodPkg        => 0, 
        :badPkg         => 1,
        :totalta        => 0,
        :statnames      => ANALYSIS_COLS_ANNS,
        :statsums       => fill(0, length(ANALYSIS_COLS_ANNS)),
        :pkgwarn        => [],
        :pkgusesite     => [],
        :pkgintr        => [],
        :tasintr        => DataFrame(),
        :tasusvar       => DataFrame(),
        :tasiusvar      => DataFrame(),
    )
    # if !isdir(pkgPath)
    #     @error "Packages directory doesn't exist: $pkgPath"
    #     return failedResult
    # end
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
            :tasiusvar  => dfius,
        )
    catch err
        @error "Problem when processing CSVs with type annptations" err
        failedResult
    end
end

addTypeAnnsAnalysis!(df :: DataFrame) = begin
    transform!(
        df, :, 
        :TypeAnnotation => ByRow(unrollAndSummarizeVars) => [
            :UnrolledTypeAnnotation, :TypeVarsSummary,
            :Error, :Warning
        ]
    )
    transform!(
        df, :, 
        :TypeVarsSummary => ByRow(getTypeAnnsAnalyses) => 
            ANALYSIS_COLS_ANNS_NOERR
    )
    df
end

unrollAndSummarizeVars(tastr) = begin
    try
        ta = tryParseAndHandleSharp(tastr)
        taFull = transformShortHand(ta).expr
        taSumm = collectTyVarsSummary(taFull)
        [string(taFull), taSumm[1], false, taSumm[2]]
    catch err
        @error "Couldn't process type annotation" tastr err
        [missing, missing, true, true]
    end
end

getTypeAnnsAnalyses(tasumm) = 
    if ismissing(tasumm)
        # excluding Error and Warning
        fill(missing, length(ANALYSIS_COLS_ANNS_NOERR))
    else
        # the number and order of functions 
        # should correspond to the elements of ANALYSIS_COLS_ANNS_NOERR
        varCnt = length(tasumm)
        hasWhere = varCnt > 0
        varsAnalyses = map(
            fun -> mkAnalysisFunction(fun)(tasumm),
            [
                tyVarUsedOnce,
                tyVarOccursAsUsedSiteVariance,
                tyVarOccursAsImpredicativeUsedSiteVariance,
                tyVarRestrictedScopePreserved,
                tyVarIsNotInLowerBound,
            ]
        )
        vcat(Any[varCnt, hasWhere], varsAnalyses)
    end

mkAnalysisFunction(fun :: Function) = (tasumm ->
    try
        fun(tasumm)
    catch err
        @error "Couldn't analyze $(Symbol(fun)) for type vars summary" tasumm err
        missing
    end
)

summarizeTypeAnnsAnalysis(df :: DataFrame) = describe(df, 
    :mean, :min, :median, :max,
    :nmissing,
    sum => :sum,
    cols = ANALYSIS_COLS_ANNS
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing type declarations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"Should coincide with the new columns added in `addTypeDeclsAnalysis!`"
const ANALYSIS_COLS_DECLS = [
    :Error, :Warning,
    :VarCnt, :TyDeclUseSiteVariance, :SuperUseSiteVariance,
]

analyzePkgTypeDecls(pkgPath :: AbstractString) :: Dict = begin
    failedResult = Dict(
        :goodPkg        => 0, 
        :badPkg         => 1,
        :totaltd        => 0,
        :statnames      => ANALYSIS_COLS_DECLS,
        :statsums       => fill(0, length(ANALYSIS_COLS_DECLS)),
        :pkgwarn        => [],
        :pkgusesite     => [],
        :tdsusvar       => DataFrame(),
    )
    # if !isdir(pkgPath)
    #     @error "Packages directory doesn't exist: $pkgPath"
    #     return failedResult
    # end
    typeDeclsPath = joinpath(pkgPath, TYPE_DECLS_FNAME)
    if !isfile(typeDeclsPath)
        @error "Type declarations file doesn't exist: $typeDeclsPath"
        return failedResult
    end
    try
        df = CSV.read(typeDeclsPath, DataFrame; escapechar='\\')
        df = addTypeDeclsAnalysis!(df)
        dfSumm = summarizeTypeDeclsAnalysis(df)
        CSV.write(
            joinpath(pkgPath, TYPE_DECLS_ANALYSIS_FNAME),
            df
        )
        CSV.write(joinpath(pkgPath, TYPE_DECLS_SUMMARY_FNAME), dfSumm)
        errOrWarn = dfSumm.sum[1] > 0 || dfSumm.sum[2] > 0
        totaltd = size(df, 1)
        dftd  = df[.!(ismissing.(df.TyDeclUseSiteVariance)) .&& 
            (.!df.TyDeclUseSiteVariance .|| .!df.SuperUseSiteVariance), :]
        dftd.Package = fill(pkgPath, size(dftd,  1))      
        Dict(
            :goodPkg    => 1, 
            :badPkg     => 0,
            :totaltd    => totaltd,
            :statnames  => dfSumm.variable,
            :statsums   => dfSumm.sum,
            :pkgwarn    => errOrWarn ? [pkgPath] : [],
            :pkgusesite => 
                (dfSumm.sum[4] < totaltd || dfSumm.sum[5] < totaltd) ? [pkgPath] : [],
            :tdsusvar   => dftd,
        )
    catch err
        @error "Problem when processing CSVs with type declarations" err
        failedResult
    end
end

addTypeDeclsAnalysis!(df :: DataFrame) = begin
    transform!(
        df, :, 
        [:TypeDeclaration,:Supertype] => ByRow(analyzeTypeDecl) => [
            :Error, :Warning,
            :VarCnt,
            :ProcessedTypeDecl, :ProcessedSuper,
            #:TypeDeclVarsSummary, :SuperVarsSummary,
            :TyDeclUseSiteVariance, :SuperUseSiteVariance,
        ]
    )
    df
end

analyzeTypeDecl(tyDeclStr, superStr) = begin
    try
        td = tryParseAndHandleSharp(tyDeclStr)
        ts = tryParseAndHandleSharp(superStr)
        (tdTy, varCnt, tsTy) = tyDeclAndSuper2FullTypes(td, ts)
        tdTyFull = transformShortHand(tdTy).expr
        tsTyFull = transformShortHand(tsTy).expr
        tdSumm = collectTyVarsSummary(tdTyFull)
        tsSumm = collectTyVarsSummary(tsTyFull)
        [
            false, tdSumm[2] || tsSumm[2],
            varCnt,
            string(tdTyFull), string(tsTyFull), 
            #tdSumm[1], tsSumm[1],
            tyVarOccursAsUsedSiteVariance(tdSumm[1]), 
            tyVarOccursAsUsedSiteVariance(tsSumm[1]),
        ]
    catch err
        @error "Couldn't process type declaration" tyDeclStr superStr err
        [true, true, missing, missing, missing, missing, missing]
    end
end

summarizeTypeDeclsAnalysis(df :: DataFrame) = describe(df, 
    :mean, :min, :median, :max,
    :nmissing,
    sum => :sum,
    cols = ANALYSIS_COLS_DECLS
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tryParseAndHandleSharp(str) = begin
    t = Meta.parse(str)
    # this might be the case due to strings like ##ANON#1
    if t === nothing
        t = Meta.parse(replace(str, '#' => 'X'))
        t !== nothing || throw(TypesAnlsUnsupportedTypeAnnotation(str))
    end
    t
end
