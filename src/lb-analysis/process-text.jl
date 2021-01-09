#######################################################################
# Analysing Julia file for lower bounds
###############################
#
# The goal is to find all occurrences of lower bounds
#   on type variables in the text of a Julia program.
#
# This can happen in 2 cases:
#   1) where T >: Int
#   2) where Int <: T <: Number
#
# So first, we need to look for both `>:` and `<:` textually
#
# If at least one of those is present, parsing Julia code
#   can give more precise results.
#######################################################################

# For Julia < 1.3 compatibility, we need `count` on strings
if VERSION < v"1.3"
    Base.count(pattern :: String, string :: String) :: Int =
        sum(map(_ -> 1, eachmatch(Regex(pattern), string)))
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Simple search of text for `<:` and `>:`
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Returns the number of occurences of constraint `constr` in `text`
countTextualConstr(constr :: ConstrKind, text :: String) :: Int =
    count(CONSTRAINT_PATTERN[constr], text)

# Returns textual constraints info for `text`
countTextualConstr(text :: String) :: TxtConstrStat =
    TxtConstrStat(
        countTextualConstr(subtc, text), 
        countTextualConstr(suptc, text))

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Analysing the text of a Julia file
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Returns `true` if there is at least one sub/sup constraint in `txtConstr`
nonVacuous(txtConstr :: TxtConstrStat) :: Bool =
    txtConstr.subConsr + txtConstr.supConsr > 0

# Returns `true` if there is at least one lower bound in `stat`
nonVacuous(stat :: LBValsFreq) :: Bool = length(stat) > 0
# LBStat|Nothing → Bool
# Returns `true` if there is at least one lower bound in `stat`
nonVacuous(stat :: LBStat)  :: Bool = stat.lbs > 0
nonVacuous(stat :: Nothing) :: Bool = false

# Computes lower-bound statistics for Julia file `file`
#   - if `isPath`, `file` means file path; otherwise, file text
# NOTE: parsing might file, in which case it records the error
lbFileInfo(file :: String; isPath :: Bool = false) :: LBFileInfo = begin
    text = file
    if isPath
        text = read(file, String)
    end
    txtConstr = countTextualConstr(text)
    if nonVacuous(txtConstr)
        try
            LBFileInfo(txtConstr, lbStatInfo(text))
        catch e
            fname = isPath ? file : "<no file>"
            info = "lbFileInfo ERR"
            isa(e, Base.Meta.ParseError) ?
                @debugonly(@warn info fname e) :
                @error info fname e
            LBFileInfo(txtConstr, e)
        end
    else
        LBFileInfo(txtConstr)
    end
end

# Computes lower-bounds statistics for the code represented by `text`
lbStatInfo(text :: String) :: LBStat =
    LBStat(extractLowerBounds(parseJuliaCode(text)))
