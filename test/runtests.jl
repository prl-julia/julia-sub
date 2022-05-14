#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using JuliaSub # if it's a registered package

# for working without installing JuliaSub it as a package
#include("../src/JuliaSub.jl")
#using Main.JuliaSub

using Test

using MacroTools
using Multisets

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const TEST_FILES_DIR = "test-files"

# String → String
testFilePath(path :: String) = joinpath(@__DIR__, TEST_FILES_DIR, path)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#include("utils.jl")
#include("lb-analysis.jl")
include("types-analysis.jl")

@testset "JuliaSub.jl" begin
    # Write your tests here.
end
