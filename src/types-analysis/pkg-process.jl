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
const EXISTININV_TYPE_ANNS_FNAME = "exist-in-inv-type-annotations.csv"
const NONTRIVCONSBNDS_TYPE_ANNS_FNAME = "non-triv-consist-bnds-type-annotations.csv"

const USESITE_TYPE_DECLS_FNAME = "non-use-site-type-declarations.csv"
const IMPUSESITE_TYPE_DECLS_FNAME = "non-imp-use-site-type-declarations.csv"
const NONTRIVCONSBNDS_TYPE_DECLS_FNAME = "non-triv-consist-bnds-type-declarations.csv"

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
            [:pkgwarn, :pkgusesite, :pkgintr, :tasintr, :tasusvar, :tasiusvar, 
             :tasexininv, :tasntrvbnd])
        combineVCat!(dtd, dtd1, dtd2, 
            [:pkgwarn, :pkgusesite, :tdsusvar, :tdsiusvar, :tdsntrvbnd])
        (dta, dtd)
    end
    (rsltta, rslttd) = reduce(combineResults, pkgResults)

    try 
        CSV.write(joinpath(pkgsDirPath, INTR_TYPE_ANNS_FNAME), rsltta[:tasintr])
        CSV.write(joinpath(pkgsDirPath, USESITE_TYPE_ANNS_FNAME), rsltta[:tasusvar])
        CSV.write(joinpath(pkgsDirPath, IMPUSESITE_TYPE_ANNS_FNAME), rsltta[:tasiusvar])
        CSV.write(joinpath(pkgsDirPath, EXISTININV_TYPE_ANNS_FNAME), rsltta[:tasexininv])
        CSV.write(joinpath(pkgsDirPath, NONTRIVCONSBNDS_TYPE_ANNS_FNAME), rsltta[:tasntrvbnd])
        CSV.write(joinpath(pkgsDirPath, USESITE_TYPE_DECLS_FNAME), rslttd[:tdsusvar])
        CSV.write(joinpath(pkgsDirPath, IMPUSESITE_TYPE_DECLS_FNAME), rslttd[:tdsiusvar])
        CSV.write(joinpath(pkgsDirPath, NONTRIVCONSBNDS_TYPE_DECLS_FNAME), rslttd[:tdsntrvbnd])
        

        CSV.write(
            joinpath(pkgsDirPath, "summary-non-imp-use-site-type-annotations.csv"),
            summarizeAnalysis(rsltta[:tasiusvar], ANALYSIS_COLS_ANNS)
        )
        CSV.write(
            joinpath(pkgsDirPath, "summary-non-use-site-type-declarations.csv"),
            summarizeAnalysis(rslttd[:tdsusvar], ANALYSIS_COLS_DECLS)
        )
    catch err
        @error "Problem when saving interesting type info" err
    end
    (rsltta, rslttd)
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const ANALYSIS_COLS_ANNS_NOERR = [
    :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance, :ImprUseSiteVariance,
    :ExistInInv, :RestrictedScope, :ClosedLowerBound, :TrivConsistBounds
]

"Should coincide with the new columns added in `addTypeAnnsAnalysis!`"
const ANALYSIS_COLS_ANNS = vcat(
    [:Error, :Warning],
    ANALYSIS_COLS_ANNS_NOERR
)
# const ANN_COLS = vcat(
#     [:File, :Function, :Kind, :TypeAnnotation],
#     ANALYSIS_COLS_ANNS,
#     [:TypeVarsSummary]
# )
# genEmptyAnnsDF() = DataFrame([col => [] for col in ANN_COLS])

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
        :tasexininv     => DataFrame(),
        :tasntrvbnd     => DataFrame(),
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
        ## reading type anns extracted from source code
        df = CSV.read(typeAnnsPath, DataFrame; escapechar='\\')
        ## reading type anns recorded dynamically
        #df = CSV.read(typeAnnsPath, DataFrame; escapechar='\\', delim=';', 
        #    header=[:TypeAnnotation])
        # TODO: either make statically exctracted CSVs use ';' or make
        # a better switch between static and dynamic info
        df = addTypeAnnsAnalysis!(df)
        dfSumm = summarizeAnalysis(df, ANALYSIS_COLS_ANNS)
        CSV.write(
            joinpath(pkgPath, TYPE_ANNS_ANALYSIS_FNAME),
            #df[:, [:File, :Function, :Kind, :TypeAnnotation, :Error, :Warning, :VarCnt, :HasWhere, :VarsUsedOnce, :UseSiteVariance, :RestrictedScope]]
            df[:, Not("TypeVarsSummary")]
        )
        CSV.write(joinpath(pkgPath, TYPE_ANNS_SUMMARY_FNAME), dfSumm)
        totalta = size(df, 1)
        dataIsNotEmpty = totalta > 0
        errOrWarn = dataIsNotEmpty && (dfSumm.sum[1] > 0 || dfSumm.sum[2] > 0)
        strongRestrictionFailed = dataIsNotEmpty && any(
            ind -> dfSumm.sum[ind] < totalta,
            [7, 8, 9]
        )
        dfta  = df[.!(ismissing.(df.ImprUseSiteVariance)) .&& 
            (.!df.ImprUseSiteVariance .|| .!df.RestrictedScope .|| 
             .!df.ClosedLowerBound .|| df.ExistInInv .|| .!df.TrivConsistBounds), :]
        dfus  = df[.!(ismissing.(df.UseSiteVariance)) .&& .!df.UseSiteVariance, :]
        dfius = df[.!(ismissing.(df.ImprUseSiteVariance)) .&& .!df.ImprUseSiteVariance, :]
        dfeii = df[.!(ismissing.(df.ExistInInv)) .&& df.ExistInInv, :]
        dfntb = df[.!(ismissing.(df.TrivConsistBounds)) .&& .!df.TrivConsistBounds, :]
        for df in [dfta, dfus, dfius, dfeii, dfntb]
            df.Package  = fill(pkgPath, size(df, 1))
        end
        # dfta.Package  = fill(pkgPath, size(dfta,  1))      
        # dfus.Package  = fill(pkgPath, size(dfus,  1))
        # dfius.Package = fill(pkgPath, size(dfius, 1))
        # dfeii.Package = fill(pkgPath, size(dfeii, 1))
        Dict(
            :goodPkg    => 1, 
            :badPkg     => 0,
            :totalta    => totalta,
            :statnames  => dfSumm.variable,
            :statsums   => dfSumm.sum,
            :pkgwarn    => errOrWarn ? [pkgPath] : [],
            :pkgusesite => (dataIsNotEmpty && dfSumm.sum[6] < totalta) ? 
                [pkgPath] : [],
            :pkgintr    => strongRestrictionFailed ? [pkgPath] : [],
            :tasintr    => dfta,
            :tasusvar   => dfus,
            :tasiusvar  => dfius,
            :tasexininv => dfeii,
            :tasntrvbnd => dfntb,
        )
    catch err
        @error "Problem when processing CSVs with type annotations" err
        failedResult
    end
end

addTypeAnnsAnalysis!(df :: DataFrame) = begin
    newColsPre = [
        :UnrolledTypeAnnotation, :TypeVarsSummary,
        :Error, :Warning
    ]
    newCols = vcat(newColsPre, ANALYSIS_COLS_ANNS_NOERR)
    if size(df)[1] > 0  
        transform!(
            df, :, :TypeAnnotation => 
                ByRow(unrollAndSummarizeVars) => newColsPre
        )
        transform!(
            df, :, :TypeVarsSummary => ByRow(getTypeAnnsAnalyses) => 
                ANALYSIS_COLS_ANNS_NOERR
        )
    else
        insertcols!(df, [col => [] for col in newCols]...)
    end
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
                existIsDeclaredInInv,
                tyVarRestrictedScopePreserved,
                tyVarIsNotInLowerBound,
                tyVarBoundsTrivConsistent,
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

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing type declarations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

"Should coincide with the new columns added in `addTypeDeclsAnalysis!`"
const ANALYSIS_COLS_DECLS = [
    :Error, :Warning,
    :VarCnt, :TyDeclUseSiteVariance, :SuperUseSiteVariance,
    :TyDeclImpUseSiteVariance, :SuperImpUseSiteVariance, :TrivConsistBounds
]
# const DECL_COLS = vcat(
#     [:File, :Name, :Kind, :TypeDeclaration, :Supertype],
#     ANALYSIS_COLS_DECLS,
#     [:ProcessedTypeDecl, :ProcessedSuper]
# )
# genEmptyDeclsDF() = DataFrame([col => [] for col in DECL_COLS])

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
        :tdsiusvar      => DataFrame(),
        :tdsntrvbnd     => DataFrame(),
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
        dfSumm = summarizeAnalysis(df, ANALYSIS_COLS_DECLS)
        CSV.write(
            joinpath(pkgPath, TYPE_DECLS_ANALYSIS_FNAME),
            df
        )
        CSV.write(joinpath(pkgPath, TYPE_DECLS_SUMMARY_FNAME), dfSumm)
        totaltd = size(df, 1)
        dataIsNotEmpty = totaltd > 0
        errOrWarn = dataIsNotEmpty && (dfSumm.sum[1] > 0 || dfSumm.sum[2] > 0)
        dftd  = df[.!(ismissing.(df.TyDeclUseSiteVariance)) .&& 
            (.!df.TyDeclUseSiteVariance .|| .!df.SuperUseSiteVariance .||
             .!df.TrivConsistBounds), :]
        dftdi = df[.!(ismissing.(df.TyDeclImpUseSiteVariance)) .&& 
            (.!df.TyDeclImpUseSiteVariance .|| .!df.SuperImpUseSiteVariance), :]
        dfntb = df[.!(ismissing.(df.TrivConsistBounds)) .&& 
            (.!df.TrivConsistBounds), :]
        for df in [dftd, dftdi, dfntb]
            df.Package  = fill(pkgPath, size(df, 1))
        end
        Dict(
            :goodPkg    => 1, 
            :badPkg     => 0,
            :totaltd    => totaltd,
            :statnames  => dfSumm.variable,
            :statsums   => dfSumm.sum,
            :pkgwarn    => errOrWarn ? [pkgPath] : [],
            :pkgusesite => (dataIsNotEmpty &&
                (dfSumm.sum[4] < totaltd || dfSumm.sum[5] < totaltd)) ? 
                [pkgPath] : [],
            :tdsusvar   => dftd,
            :tdsiusvar  => dftdi,
            :tdsntrvbnd => dfntb,
        )
    catch err
        @error "Problem when processing CSVs with type declarations" err
        failedResult
    end
end

addTypeDeclsAnalysis!(df :: DataFrame) = begin
    newCols = [
        :Error, :Warning,
        :VarCnt,
        :ProcessedTypeDecl, :ProcessedSuper,
        #:TypeDeclVarsSummary, :SuperVarsSummary,
        :TyDeclUseSiteVariance, :SuperUseSiteVariance,
        :TyDeclImpUseSiteVariance, :SuperImpUseSiteVariance,
        :TrivConsistBounds
    ]
    if size(df)[1] > 0  
        transform!(
            df, :, [:TypeDeclaration,:Supertype] => 
                ByRow(analyzeTypeDecl) => newCols
        )
    else
        insertcols!(df, [col => [] for col in newCols]...)
    end
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
            tyVarOccursAsImpredicativeUsedSiteVariance(tdSumm[1]), 
            tyVarOccursAsImpredicativeUsedSiteVariance(tsSumm[1]),
            tyVarBoundsTrivConsistent(tdSumm[1]) && tyVarBoundsTrivConsistent(tsSumm[1]),
        ]
    catch err
        @error "Couldn't process type declaration" tyDeclStr superStr err
        vcat([true, true], fill(missing, 8))
    end
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

summarizeAnalysis(df :: DataFrame, analysisCols) = 
    size(df)[1] > 0 ?
        describe(df, 
            :mean, :min, :median, :max, :nmissing,
            sum => :sum,
            cols = analysisCols
        ) :
        begin
            dfSumm = DataFrame(
                [col => fill(0, length(analysisCols)) for col in 
                [:mean, :min, :median, :max, :nmissing, :sum]])
            dfSumm.variable = analysisCols
            dfSumm
        end

tryParseAndHandleSharp(str) = begin
    t = Meta.parse(str)
    # this might be the case due to strings like ##ANON#1
    if t === nothing
        t = Meta.parse(replace(str, '#' => 'X'))
        t !== nothing || throw(TypesAnlsUnsupportedTypeAnnotation(str))
    end
    t
end
