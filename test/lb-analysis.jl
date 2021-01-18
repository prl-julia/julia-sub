#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: countTextualConstr
using Main.JuliaSub: subtc, suptc
using Main.JuliaSub: TxtConstrStat, LBValsFreq, LBStat, FileLBInfo
using Main.JuliaSub: extractLowerBound, extractLowerBounds
using Main.JuliaSub: nonVacuous, lbStatInfo, lbFileInfo
using Main.JuliaSub: FilesLBInfo, PackageStat
using Main.JuliaSub: processPkg, processPkgsDir

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Aux values and functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Analysis relies on the fact that there are only few patterns
# where a lower bound can appear.
# If language changes and there are more, the analysis needs
# to be extended
@testset "lb-analysis :: type bounds format" begin
    @test (Meta.parse("f(x::T) where T = 0"); true)
    @test (Meta.parse("f(x::T) where T<:Number = 0"); true)
    @test (Meta.parse("f(x::T) where T>:Int = 0"); true)
    @test (Meta.parse("f(x::T) where Int<:T<:Number = 0"); true)
    @test (Meta.parse("Vector{>:Int}"); true)

    @test_throws Exception (eval(Meta.parse("f(x::T) where Number>:T>:Int = 0")); true)
    @test_throws UndefVarError (eval(Meta.parse("f(x::T) where Int<:T = 0")); true)
end

@testset "lb-analysis :: sub/sup symbols" begin
    @test countTextualConstr(subtc, "")  == 0
    @test countTextualConstr(subtc, ":") == 0
    @test countTextualConstr(subtc, "<") == 0
    @test countTextualConstr(subtc, ">:")  == 0
    @test countTextualConstr(suptc, "  ab ") == 0
    @test countTextualConstr(suptc, "> :") == 0
    @test countTextualConstr(suptc, "<:")  == 0

    @test countTextualConstr(subtc, "<:")   == 1
    @test countTextualConstr(subtc, "<:<")  == 1
    @test countTextualConstr(suptc, ">:")   == 1
    @test countTextualConstr(suptc, "{>:}") == 1
    @test countTextualConstr(suptc, " >::") == 1

    @test countTextualConstr(subtc, "where T <: Int") == 1
    @test countTextualConstr(subtc, "where Int<:T<:Number") == 2
    @test countTextualConstr(suptc, "where T >:   Int ") == 1

    @test countTextualConstr("<: T>:Int Nothing<:S<:Number") ==
        TxtConstrStat(3, 1)
    @test countTextualConstr("< : T>:Int >:>: S>:Number </:") ==
        TxtConstrStat(0, 4)
end

@testset "lb-analysis :: capture direct lower bound" begin
    @test extractLowerBound(:(<:Int)) == nothing
    @test extractLowerBound(:(T <: Number)) == nothing
    @test extractLowerBound(:(Number>:T>:Int)) == nothing

    @test extractLowerBound(:(>:Int)) == :Int
    @test extractLowerBound(:(T>:Int)) == :Int
    @test extractLowerBound(:( T >: Nothing )) == :Nothing
    @test extractLowerBound(:(Int <: T <: Bool)) == :Int
end

@testset "lb-analysis :: capture lower bounds" begin
    @test extractLowerBounds(:(g(xs::Vector{<:Real}) = 0)) ==
        Multiset()
    @test extractLowerBounds(:(f(x::T) where T = 0)) ==
        Multiset()

    @test extractLowerBounds(:(g(xs::Vector{>:Int}) = 0)) ==
        Multiset(:Int)
    @test extractLowerBounds(:(g(xs::Dict{>:String, >:Int}) = 0)) ==
        Multiset(:String, :Int)
    
    @test extractLowerBounds(:(f(x::T) where T>:Int)) ==
        Multiset(:Int)
    @test extractLowerBounds(:(f(x::T) where {T>:Int, Nothing<:S<:Number} = 0)) ==
        Multiset(:Int, :Nothing)
    @test extractLowerBounds(:(f(x::T) where Int<:T where S<:Number = 0)) ==
        Multiset()
    @test extractLowerBounds(:(f(x::T) where T>:Int where S>:Int = 0)) ==
        Multiset(:Int, :Int)
    @test extractLowerBounds(:(f(x::T) where Int<:T<:S where S<:Number = 0)) ==
        Multiset(:Int)
    @test extractLowerBounds(:(f(x::T) where Int<:T<:S where S<:Number where U>:Bool = 0)) ==
        Multiset(:Int, :Bool)
    @test extractLowerBounds(:(f(x::T) where Int<:T<:S where {S<:Number, Int<:Q<:Nothing} where U>:Bool = 0)) ==
        Multiset(:Int, :Int, :Bool)
    @test extractLowerBounds(quote 
            f(x) = 5
            f(x, y::T) where T>:S where S = x
            const X = 7
            g(x::T) where {Int<:T<:Number, S<:Bool} = x
            h(d::Dict{K,>:Int}) where K<:Vector{>:Bool} :: Vector{>:Missing} = d
        end) ==
        Multiset(:Int, :S, :Int, :Bool, :Missing)
end

@testset "lb-analysis :: nonVacuous" begin
    @test nonVacuous(TxtConstrStat(1, 0))
    @test nonVacuous(TxtConstrStat(0, 6))
    @test nonVacuous(TxtConstrStat(4, 1))
    @test !nonVacuous(TxtConstrStat(0, 0))
end

@testset "lb-analysis :: lower-bounds statistics" begin
    @test lbStatInfo("f(x::T) where T>:Int = 0") ==
        LBStat(1, 1, LBValsFreq(:Int))
    @test lbStatInfo("f(x::T) where {T>:Int, Int<:S<:Number} = 0") ==
        LBStat(2, 1, LBValsFreq(:Int, :Int))
    @test lbStatInfo("f(x::T) where {T>:Int, Int<:S<:Number, Q>:Missing} = 0") ==
        LBStat(3, 2, LBValsFreq(:Int, :Int, :Missing))
end

@testset "lb-analysis :: lower-bounds file statistics" begin
    @test lbFileInfo("")  == FileLBInfo(TxtConstrStat())
    @test lbFileInfo("<") == FileLBInfo(TxtConstrStat())
    @test lbFileInfo(">:") ==
        FileLBInfo(TxtConstrStat(0,1), LBStat(LBValsFreq()))
    @test lbFileInfo("f(x::T) where {T>:Int, Int<:S<:Number, Q>:Missing} = 0") ==
        FileLBInfo(TxtConstrStat(2,2), LBStat(LBValsFreq(:Int, :Int, :Missing)))

    @test lbFileInfo(testFilePath("fRet10.jl"); isPath=true) ==
        FileLBInfo(TxtConstrStat(3,4), LBStat(LBValsFreq(:Int, :Bool, :Nothing, :String, :T)))

    failedFileLBInfo = lbFileInfo("f(x::T) wher T>:Int = 0")
    @test failedFileLBInfo.txtStat == TxtConstrStat(0, 1)
    @test isa(failedFileLBInfo.err, Base.Meta.ParseError)
    @test failedFileLBInfo.lbStat == nothing
end

@testset "lb-analysis :: lower-bounds package statistics" begin
    pkgBad = "FAKE-bad.jl"
    pkgStatBad = PackageStat(pkgBad, false)
    @test processPkg(testFilePath(joinpath("pkgs", pkgBad)), pkgBad) ==
        pkgStatBad
        
    pkgGood = "FAKE-fRet10.jl"
    pkgStatGood = PackageStat(
        pkgGood, true, 3, 0, 2,
        FilesLBInfo(
            joinpath("src", "fRet10.jl") => 
                FileLBInfo(TxtConstrStat(3,4), LBStat(LBValsFreq(:Int, :Bool, :Nothing, :String, :T))),
            joinpath("src", "id.jl") =>
                FileLBInfo(TxtConstrStat(0,2), LBStat(LBValsFreq(:Any, :Int)))),
        LBStat(LBValsFreq(:Int,:Int, :Bool, :Nothing, :Any, :String, :T)))
    @test processPkg(testFilePath(joinpath("pkgs", pkgGood)), pkgGood) ==
        pkgStatGood

    (badPkgs, goodPkgs, totalStat) = processPkgsDir(testFilePath("pkgs"))
    getName(pkg :: PackageStat) = pkg.name
    @test badPkgs == [pkgStatBad]
    @test sort(goodPkgs, by=getName) == 
        sort([pkgStatGood, PackageStat("FAKE-empty.jl", true)], by=getName)
    @test totalStat == LBStat(7, 6, LBValsFreq(:Int,:Int, :Bool, :Nothing, :Any, :String, :T))
end
