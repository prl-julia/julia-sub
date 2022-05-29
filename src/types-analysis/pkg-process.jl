#######################################################################
# Processing package source code for type annotations
###############################
#
# TODO
#
#######################################################################

const TYPE_ANNS_FNAME = "type-annotations.csv"

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
        write(
            destFileIO,
            jlFilePathInPkg * "," * csvLineString(tyAnn)
        )
    end
end

