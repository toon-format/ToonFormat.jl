# Options

Pass `EncodeOptions` to `encode` and `DecodeOptions` to `decode` through the `options` keyword:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `indentSize` | `2` | Spaces per indentation level (encode and decode) |
| `delimiter` | `COMMA` | Delimiter for inline arrays and tabular rows: `COMMA`, `TAB`, or `PIPE` (encode) |
| `strict` | `true` | Throws on every decode error of the spec; `false` applies its five non-strict recoveries instead (decode) |

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

Strict mode throws on every [decode error](https://github.com/toon-format/spec/blob/v4.4.0/SPEC.md#14-decode-errors-and-non-strict-recoveries-authoritative-checklist) the spec lists. `strict = false` recovers from five of them and throws on the rest:

- A declared length is advisory: every value, row, item, and entry present is decoded, though each row still needs one cell per field
- Duplicate keys and repeated field names keep the last value
- Each tab in the indentation counts as one level, and the spaces count in whole levels, rounded down
- Blank lines between the rows, items, or entries of a header are skipped
- A block whose first line is indented more than one level deeper reads at that depth

Here it keeps the rows that are present:

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
