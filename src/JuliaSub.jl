module JuliaSub

#--------------------------------------------------
# Imports
#--------------------------------------------------

using MacroTools
using Multisets
using DataStructures
using Distributed
using DataFrames
using CSV

#--------------------------------------------------
# Files
#--------------------------------------------------

include("utils/lib.jl")
include("lb-analysis/lib.jl")
include("types-analysis/lib.jl")

#--------------------------------------------------
# Exports
#--------------------------------------------------

export collectAndSaveTypeAnns2CSV, analyzePkgTypeAnnsAndSave2CSV
export collectTyVarsSummary

#--------------------------------------------------
# Code
#--------------------------------------------------

VERBOSE = true
DEBUG = true

# print analysis info every this number of packages
const PKGS_NUM_STEP = 100

setVerbose(verbose :: Bool) = begin
    global VERBOSE = verbose
end

end
