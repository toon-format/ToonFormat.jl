# Host-type mapping, which the fixtures can't express.
@testset "Host Types" begin
    @testset "encode($(repr(value)))" for (value, expected) in [
        (b = 1, a = 2) => "b: 1\na: 2",
        ["b" => 1, "a" => 2] => "b: 1\na: 2",
        (:b => 1, :a => 2) => "b: 1\na: 2",
        ["a" => 1, "b" => 2, "a" => 3] => "a: 3\nb: 2",
        (outer = (inner = 42,),) => "outer:\n  inner: 42",
        NamedTuple() => "",
        (1, 2, 3) => "[3]: 1,2,3",
        (1, :a => 2) => "[2]: 1,\":a => 2\"",
        Set([1]) => "[1]: 1",
        [1 2; 3 4] => "[4]: 1,3,2,4",
        [NaN, Inf, -Inf, -0.0] => "[4]: null,null,null,0",
        big"1e400" => "\"1.000000000000000000000000000000000000000000000000000000000000000000000000000003e+400\"",
        1 + 2im => "1 + 2im",
        :sym => "sym",
        missing => "missing",
    ]
        @test encode(value) == expected
    end

    @testset "decode($(repr(input)))" for (input, expected) in [
        "42" => 42,
        "3.5" => 3.5,
        "99999999999999999999" => big"99999999999999999999",
        "1e999" => "1e999",
    ]
        decoded = decode(input)
        @test isequal(decoded, expected) && typeof(decoded) == typeof(expected)
    end
end
