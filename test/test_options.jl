@testset "Options" begin
    @test_throws ArgumentError EncodeOptions(delimiter = ";")
end
