# Options

Pass `EncodeOptions` to `encode` and `DecodeOptions` to `decode` through the `options` keyword:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `indentSize` | `2` | Spaces per indentation level (encode and decode) |
| `delimiter` | `COMMA` | Delimiter for inline arrays and tabular rows: `COMMA`, `TAB`, or `PIPE` (encode) |
| `strict` | `true` | Throws on the spec's strict-mode errors instead of applying its non-strict leniencies (decode) |

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

Strict mode throws on every [strict-mode error](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md#14-strict-mode-errors-and-diagnostics-authoritative-checklist) the spec lists. `strict = false` applies the spec's non-strict leniencies instead – here it keeps the rows that are present:

```julia
toon = """
users[3]{id,name,role}:
  1,Ada,admin
  2,Bob,user"""

decode(toon)
# ERROR: Line 3: Expected 3 tabular rows, but got 2

decode(toon; options = DecodeOptions(strict = false))
# OrderedDict("users" => [OrderedDict("id" => 1, "name" => "Ada", "role" => "admin"), OrderedDict("id" => 2, "name" => "Bob", "role" => "user")])
```
