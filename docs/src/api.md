# API Reference

```@docs
ToonFormat.encode
ToonFormat.decode
```

## Options

```julia
EncodeOptions(; indent = 2, delimiter = COMMA, keyFolding = "off", flattenDepth = typemax(Int))
DecodeOptions(; indent = 2, strict = true, expandPaths = "off")
```

[Options](options.md) describes each field. `COMMA`, `TAB`, and `PIPE` are the exported delimiter constants.
