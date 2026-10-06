@testset "Options" begin
    @test_throws ArgumentError EncodeOptions(delimiter = ";")
    @test_throws ArgumentError EncodeOptions(indentSize = 0)
    @test_throws ArgumentError DecodeOptions(indentSize = 0)
end
