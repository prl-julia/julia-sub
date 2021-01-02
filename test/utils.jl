#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: parseJuliaCode, parseJuliaFile

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

const QUOTE = :quote
const BLOCK = :block

const EMPTY_BLOCK = Expr(BLOCK)

# Wraps `expr` in quote expression
wrapQuote(expr) = Expr(QUOTE, expr)
# Wraps `expr` in block expression
wrapBlock(expr) = Expr(BLOCK, expr)

# Checks that after stripping line numbers,
# `testee` is equal to quoted `reference`
parseTest(testee, reference) =
    MacroTools.prewalk(rmlines, testee) == wrapQuote(reference)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "utils :: parsing Julia" begin
    @test parseTest(parseJuliaCode(""), EMPTY_BLOCK)
    @test parseTest(parseJuliaFile(testFilePath("empty.jl")), EMPTY_BLOCK)

    @test parseTest(parseJuliaCode("5"), wrapBlock(5))
    @test parseTest(parseJuliaFile(testFilePath("const10.jl")),
            wrapBlock(:(const N = 10)))
end

#--------------------------------------------------
