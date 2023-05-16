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
                TypeDeclInfo(tdstrc, :( Multiset{T} ), :( AbstractSet{T} ))
            )
        )
end

@testset "JuliaSub.jl :: packages processing            " begin
    mkdir(testFilePath("ta-info"))

    tainfo = collectAndSaveTypeInfo2CSV(
        testFilePath("pkgs-ta/2"), testFilePath("ta-info/2")
    )
    @JuliaSub.status tainfo
    @test isdir(testFilePath("ta-info/2"))
    @test isdir(testFilePath("ta-info/2/DataStructures.jl"))
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/type-annotations.csv"))
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/type-declarations.csv"))
    @test isdir(testFilePath("ta-info/2/Gen.jl"))
    @test isfile(testFilePath("ta-info/2/Gen.jl/type-annotations.csv"))
    @test isfile(testFilePath("ta-info/2/Gen.jl/type-declarations.csv"))

    taanalysis = analyzePkgTypeAnnsAndSave2CSV(testFilePath("ta-info/2"))
    @JuliaSub.status taanalysis
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/analyzed-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/summary.csv"))
    @test isfile(testFilePath("ta-info/2/Gen.jl/summary.csv"))

    @test isfile(testFilePath("ta-info/2/interesting-type-annotations.csv"))

    tryrm(testFilePath("ta-info"))
end
