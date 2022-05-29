#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using JuliaSub # if it's a registered package

# for working without installing JuliaSub as a package
#include("../src/JuliaSub.jl")
#using Main.JuliaSub

using Test

using MacroTools
using Multisets
using DataStructures

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const TEST_FILES_DIR      = "test-files"
const TEST_FILES_DIR_PATH = joinpath(@__DIR__, TEST_FILES_DIR)

# String → String
testFilePath(path :: AbstractString) = joinpath(TEST_FILES_DIR_PATH, path)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# FIXME
#include("utils.jl")
#include("lb-analysis.jl")
include("types-analysis.jl")

@testset "JuliaSub.jl" begin
    # Write your tests here.
end
