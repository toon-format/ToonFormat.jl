# Options

Pass `EncodeOptions` to `encode` and `DecodeOptions` to `decode` through the `options` keyword:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `indent` | `2` | Spaces per indentation level (encode and decode) |
| `delimiter` | `COMMA` | Array delimiter: `COMMA`, `TAB`, or `PIPE` (encode) |
| `strict` | `true` | Raise the strict-mode errors of spec §14 (decode) |

## Delimiters

The delimiter appears in the header and separates the values of every row:

```julia
users = [(id = 1, name = "Ada", role = "admin"), (id = 2, name = "Bob", role = "user")]
encode((users = users,); options = EncodeOptions(delimiter = PIPE))
# users[2|]{id|name|role}:
#   1|Ada|admin
#   2|Bob|user
```

`decode` reads the delimiter from each header and needs no option.

## Strict Mode

Strict mode throws on every error listed in [§14](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md#14-strict-mode-errors-and-diagnostics-authoritative-checklist). `strict = false` accepts what it can instead – here the rows that are present:

```julia
toon = """
users[3]{id,name,role}:
  1,Ada,admin
  2,Bob,user"""

decode(toon)
# ERROR: Array length mismatch: expected 3, got 2

decode(toon; options = DecodeOptions(strict = false))
# OrderedDict("users" => [OrderedDict("id" => 1, "name" => "Ada", "role" => "admin"), OrderedDict("id" => 2, "name" => "Bob", "role" => "user")])
```
