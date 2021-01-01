#######################################################################
# Utilities for parsing Julia files
#######################################################################

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Parsing Julia files
#
#   Based on
#   https://discourse.julialang.org/t/parsing-a-julia-file/32622
#
#=
parsefile(file) = parse(join(["quote", readstring(file), "end"], ";"))
parsecode(code::String)::Vector =
    # https://discourse.julialang.org/t/parsing-a-julia-file/32622
    filter(x->!(x isa LineNumberNode),
           Meta.parse(join(["quote", code, "end"], ";")).args[1].args)
=#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# String → AST
# Parses `text` as Julia code
parseJuliaCode(text :: String) =
    Meta.parse(join(["quote", text, "end"], "\n"))

# String → AST
# Parses file `filePath` as Julia code
parseJuliaFile(filePath :: String) =
    parseJuliaCode(read(filePath, String))
