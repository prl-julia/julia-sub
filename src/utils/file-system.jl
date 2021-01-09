#######################################################################
# Utilities for working with a file system
#######################################################################

# Returns a list of (dPath, dName) for every subdirectory of `dirPath`
# ASSUMPTION: `dirPath` is a path to a directory
subdirPathsWithNames(dirPath :: String) :: Vector{Tuple{String, String}} = begin
    pathsWithNames = map(
        name -> (joinpath(dirPath, name), name),
        readdir(dirPath)
    )
    filter(pn -> isdir(pn[1]), pathsWithNames)
end
