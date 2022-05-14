module JuliaSub

#--------------------------------------------------
# Imports
#--------------------------------------------------

using MacroTools
using Multisets

#--------------------------------------------------
# Files
#--------------------------------------------------

include("utils/lib.jl")
include("lb-analysis/lib.jl")
include("types-analysis/lib.jl")

#--------------------------------------------------
# Exports
#--------------------------------------------------

#--------------------------------------------------
# Code
#--------------------------------------------------

VERBOSE = true
DEBUG = true

# print analysis info every this number of packages
const PKGS_NUM_STEP = 100

end
