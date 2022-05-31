#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tests
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

@testset "JuliaSub.jl :: packages processing            " begin
    mkdir(testFilePath("ta-info"))

    tainfo = collectAndSaveTypeAnns2CSV(
        testFilePath("pkgs-ta/2"), testFilePath("ta-info/2")
    )
    @JuliaSub.status tainfo
    @test isdir(testFilePath("ta-info/2"))
    @test isdir(testFilePath("ta-info/2/DataStructures.jl"))
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/type-annotations.csv"))
    @test isdir(testFilePath("ta-info/2/Gen.jl"))
    @test isfile(testFilePath("ta-info/2/Gen.jl/type-annotations.csv"))

    taanalysis = analyzePkgTypeAnnsAndSave2CSV(testFilePath("ta-info/2"))
    @JuliaSub.status taanalysis
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/analyzed-type-annotations.csv"))
    @test isfile(testFilePath("ta-info/2/DataStructures.jl/summary.csv"))
    @test isfile(testFilePath("ta-info/2/Gen.jl/summary.csv"))

    @test isfile(testFilePath("ta-info/2/interesting-type-annotations.csv"))

    tryrm(testFilePath("ta-info"))
end
