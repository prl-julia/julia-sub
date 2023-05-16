#!/usr/bin/env julia

#######################################################################
# TODO
###############################
#
# $ 
#
# FIXME: reload parameter is not supported
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
        "pkgs"
            help = "directory with Julia packages"
            arg_type = String
            required = true
        "dest"
            help = "directory for outputting CSV files with extracted type annotations"
            arg_type = String
            required = true
        #=
        "--reload", "-r"
            help = "flag specifying if packages information must be reloaded"
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

println("Initiating type annotations collection...")
result = collectAndSaveTypeInfo2CSV(
    PARAMS["pkgs"], PARAMS["dest"]
)
for (k, v) in result
    println(k)
    println(v)
    println("\n")
end
