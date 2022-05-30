#!/usr/bin/env julia

#######################################################################
# TODO
###############################
#
# $ 
#
# 
#######################################################################

#--------------------------------------------------
# Imports
#--------------------------------------------------

using JuliaSub
using ArgParse

#--------------------------------------------------
# Command line arguments
#--------------------------------------------------

# → Dict (arguments)
function parse_command_line_args()
    argsStr = ArgParseSettings(
        description = "Collects type annotations from Julia source files"
    )
    @add_arg_table! argsStr begin
        "pkginfos"
            help = "directory of folders with collected type annotations for packages"
            arg_type = String
            required = true
        
        "--reload", "-r"
            help = "flag specifying if analysis files should be rewritten"
            action = :store_true
    end
    parse_args(argsStr)
end

# All script parameters
const PARAMS = parse_command_line_args()

#--------------------------------------------------
# Main
#--------------------------------------------------

@info "Initiating type annotations analysis..."
resultStats = analyzePkgTypeAnnsAndSave2CSV(PARAMS["pkginfos"])
for (k,v) in resultStats
    @info "Total $k:" v
end
