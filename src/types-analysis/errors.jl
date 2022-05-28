#######################################################################
# Errors related to analysis of type annotations
#######################################################################

abstract type TypesAnalysisException <: Exception end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Extracting type annotations
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

struct TypesAnlsBadMethodParamAST
    ast :: Any
end
