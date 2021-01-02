include("src/JuliaSub.jl")

using Multisets

folder = ARGS[1]

computeStat(text :: String) = begin
    constrsCnt = JuliaSub.countTextualConstr(JuliaSub.subtc, text) +
        JuliaSub.countTextualConstr(JuliaSub.suptc, text)
    if constrsCnt == 0
        Multiset()
    else
        JuliaSub.extractLowerBounds(JuliaSub.parseJuliaCode(text))
    end
end

# String → Bool
isJuliaFile(fname :: String) :: Bool = endswith(fname, ".jl")

processPkg(pkgPath :: String) :: Multiset = begin
    res = Multiset()
    # we assume that correct Julia packages have [src] folder
    srcPath = joinpath(pkgPath, "src")
    isdir(srcPath) || return res
    # recursively walk all files in [src]
    for (root, _, files) in walkdir(srcPath)
        # we are only interested in Julia files
        files = filter(isJuliaFile, files)
        for file in files
            filePath = joinpath(root, file)
            try
                fileInfo = computeStat(read(filePath, String))
                mergewith!(res, fileInfo)
            catch e
                @error e
            end
        end
    end
    res
end

gatherAllStat(path :: String) = begin
    paths = map(name -> (joinpath(path, name), name), readdir(path))
    dirs  = filter(d -> isdir(d[1]), paths)
    res = Multiset()
    for pkgPath in dirs
        pkgInfo = processPkg(pkgPath[1])
        if length(pkgInfo) != 0
            println(pkgPath[2])
            println(pkgInfo.data)
            println("===========================================\n\n")
        end
        mergewith!(res, pkgInfo)
    end
    println(res.data)
end

gatherAllStat(folder)