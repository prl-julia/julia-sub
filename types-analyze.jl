#!/usr/bin/env julia

#######################################################################
# TODO
###############################
#
# $ 
#
# FIXME: reload
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
        
        #=
        "--reload", "-r"
            help = "flag specifying if analysis files should be rewritten"
            action = :store_true
        =#
    end
    parse_args(argsStr)
end

# All script parameters
const PARAMS = parse_command_line_args()

#--------------------------------------------------
# Main
#--------------------------------------------------

printResult(resultStats) = begin
    for (k,v) in resultStats
        !(k in [:statnames, :statsums]) &&
            @info "Total $k:" v
    end
    for i in 1:length(resultStats[:statnames])
        @info "Total $(resultStats[:statnames][i]):\n $(resultStats[:statsums][i])"
    end
end

@info "Initiating type annotations analysis..."
(resultStatsTA, resultStatsTD) = analyzePkgTypesAndSave2CSV(PARAMS["pkginfos"])
@info "*** TYPE ANNOTATIONS\n"
printResult(resultStatsTA)
@info "\n*** TYPE DECLARATIONS\n"
printResult(resultStatsTD)
