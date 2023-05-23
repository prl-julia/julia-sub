#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Imports
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

using Main.JuliaSub: TypeInfo, parseAndCollectTypeInfo

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "types-analysis :: collect all ty-info in file " begin
    @test parseAndCollectTypeInfo(testFilePath("empty.jl")) == TypeInfo()

    @test parseAndCollectTypeInfo(
            testFilePath("Multisets-cut.jl")
        ) == TypeInfo(
            list(
                TypeAnnInfo(:push!, mtsig, :( Tuple{Multiset{T}, Any, Int} where T )),
                TypeAnnInfo(:getindex, retty, :Int), 
                TypeAnnInfo(:getindex, mtsig, :( Tuple{Multiset{T}, Any} where T )),
                TypeAnnInfo(:clean!, mtsig, :( Tuple{Multiset} )),
                TypeAnnInfo(:Multiset, mtsig, :( Tuple{Base.AbstractSet{T}} where T )),
                TypeAnnInfo(:Multiset, mtsig, :(( Tuple{AbstractArray{T, d}} where d) where T )), 
                TypeAnnInfo(:eltype, mtsig, :( Tuple{Multiset{T}} where T )),
                TypeAnnInfo(:(Base.empty!), mtsig, :( Tuple{Multiset{T}} where T )),
                TypeAnnInfo(:(Base.copy), mtsig, :( Tuple{Multiset{T}} where T )),
                TypeAnnInfo(:Multiset, mtsig, :( Tuple{Vararg{Any}} )),
                TypeAnnInfo(:Multiset, mtsig, :( Tuple{} )),
                TypeAnnInfo(:Multiset, mtsig, :( Tuple{} where T )),
                TypeAnnInfo(NOTAFUNSIG, tyassorann, :( Dict{T,Int} ))
            ),
            list(
                TypeDeclInfo(:Multiset, tdstrc, :( Multiset{T} ), :( AbstractSet{T} ))
            )
        )
end

@testset "JuliaSub.jl :: packages processing            " begin
    mkdir(testFilePath("ta-info"))

    tainfo = collectAndSaveTypeInfo2CSV(
        testFilePath("pkgs-ta/3"), testFilePath("ta-info/3")
    )
    @JuliaSub.status tainfo
    @test isdir(testFilePath("ta-info/3"))
    @test isdir(testFilePath("ta-info/3/DataStructures.jl"))
    @test isfile(testFilePath("ta-info/3/DataStructures.jl/type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/DataStructures.jl/type-declarations.csv"))
    @test isdir(testFilePath("ta-info/3/Gen.jl"))
    @test isfile(testFilePath("ta-info/3/Gen.jl/type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/Gen.jl/type-declarations.csv"))

    tyanalysis = analyzePkgTypesAndSave2CSV(testFilePath("ta-info/3"))
    @JuliaSub.status tyanalysis
    @test isfile(testFilePath("ta-info/3/DataStructures.jl/analyzed-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/DataStructures.jl/summary-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/Gen.jl/analyzed-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/Gen.jl/summary-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/DataStructures.jl/analyzed-type-declarations.csv"))
    @test isfile(testFilePath("ta-info/3/DataStructures.jl/summary-type-declarations.csv"))
    @test isfile(testFilePath("ta-info/3/Gen.jl/analyzed-type-declarations.csv"))
    @test isfile(testFilePath("ta-info/3/Gen.jl/summary-type-declarations.csv"))

    @test isfile(testFilePath("ta-info/3/interesting-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/non-use-site-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/non-imp-use-site-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/3/non-use-site-type-declarations.csv"))
    @test isfile(testFilePath("ta-info/3/non-imp-use-site-type-declarations.csv"))

    tryrm(testFilePath("ta-info"))
end
