# Examples

Real-world examples demonstrating ToonFormat.jl usage.

## Configuration Files

### Application Config

```julia
using ToonFormat

config = Dict(
    "app" => Dict(
        "name" => "MyApp",
        "version" => "1.0.0",
        "debug" => false
    ),
    "server" => Dict(
        "host" => "0.0.0.0",
        "port" => 8080,
        "workers" => 4
    ),
    "database" => Dict(
        "type" => "postgresql",
        "host" => "localhost",
        "port" => 5432,
        "name" => "myapp_db"
    ),
    "logging" => Dict(
        "level" => "info",
        "file" => "/var/log/myapp.log"
    )
)

# Encode to TOON
toon_str = TOON.encode(config)
println(toon_str)

# With key folding for flatter structure
options = TOON.EncodeOptions(keyFolding="safe", flattenDepth=2)
toon_str = TOON.encode(config, options=options)
println(toon_str)
```

## Data Processing

### User Records

```julia
using ToonFormat

users = [
    Dict("id" => 1, "name" => "Alice", "email" => "alice@example.com", "active" => true),
    Dict("id" => 2, "name" => "Bob", "email" => "bob@example.com", "active" => true),
    Dict("id" => 3, "name" => "Charlie", "email" => "charlie@example.com", "active" => false)
]

# Encode as tabular data (very compact)
toon_str = TOON.encode(Dict("users" => users))
println(toon_str)
# users[3]{id,name,email,active}:
#   1,Alice,alice@example.com,true
#   2,Bob,bob@example.com,true
#   3,Charlie,charlie@example.com,false

# Save to file
write("users.toon", toon_str)

# Load from file
loaded_str = read("users.toon", String)
data = TOON.decode(loaded_str)
```

### Time Series Data

```julia
using ToonFormat, Dates

# Generate time series data
timestamps = [DateTime(2024, 1, 1) + Hour(i) for i in 0:23]
temperatures = [20.0 + 5 * sin(i * π / 12) for i in 0:23]

data = [
    Dict("time" => string(t), "temp" => round(temp, digits=1))
    for (t, temp) in zip(timestamps, temperatures)
]

# Encode with tab delimiter for TSV-like format
options = TOON.EncodeOptions(delimiter=TOON.TAB)
toon_str = TOON.encode(Dict("readings" => data), options=options)
println(toon_str)
```

## API Responses

### REST API Response

```julia
using ToonFormat

response = Dict(
    "status" => "success",
    "code" => 200,
    "data" => Dict(
        "user" => Dict(
            "id" => 123,
            "username" => "alice",
            "email" => "alice@example.com",
            "profile" => Dict(
                "firstName" => "Alice",
                "lastName" => "Smith",
                "age" => 30
            )
        ),
        "permissions" => ["read", "write", "admin"]
    ),
    "meta" => Dict(
        "timestamp" => "2024-01-01T12:00:00Z",
        "requestId" => "abc-123-def"
    )
)

# Encode for LLM context (compact)
toon_str = TOON.encode(response)
println(toon_str)

# Token count comparison
using JSON
json_str = JSON.json(response)
println("JSON length: $(length(json_str))")
println("TOON length: $(length(toon_str))")
println("Reduction: $(round((1 - length(toon_str)/length(json_str)) * 100, digits=1))%")
```

### Paginated Results

```julia
using ToonFormat

results = Dict(
    "page" => 1,
    "perPage" => 10,
    "total" => 100,
    "items" => [
        Dict("id" => i, "title" => "Item $i", "price" => 10.0 * i)
        for i in 1:10
    ],
    "links" => Dict(
        "self" => "/api/items?page=1",
        "next" => "/api/items?page=2",
        "last" => "/api/items?page=10"
    )
)

toon_str = TOON.encode(results)
println(toon_str)
```

## Machine Learning

### Training Data

```julia
using ToonFormat

# Training examples
training_data = [
    Dict("features" => [1.0, 2.0, 3.0], "label" => 0),
    Dict("features" => [2.0, 3.0, 4.0], "label" => 1),
    Dict("features" => [3.0, 4.0, 5.0], "label" => 1)
]

# Encode for storage
toon_str = TOON.encode(Dict("training" => training_data))
write("training.toon", toon_str)

# Load for training
loaded = TOON.decode(read("training.toon", String))
X = hcat([d["features"] for d in loaded["training"]]...)'
y = [d["label"] for d in loaded["training"]]
```

### Model Metadata

```julia
using ToonFormat

metadata = Dict(
    "model" => Dict(
        "type" => "neural_network",
        "architecture" => "feedforward",
        "layers" => [
            Dict("type" => "dense", "units" => 128, "activation" => "relu"),
            Dict("type" => "dropout", "rate" => 0.2),
            Dict("type" => "dense", "units" => 64, "activation" => "relu"),
            Dict("type" => "dense", "units" => 10, "activation" => "softmax")
        ]
    ),
    "training" => Dict(
        "optimizer" => "adam",
        "learningRate" => 0.001,
        "batchSize" => 32,
        "epochs" => 100
    ),
    "metrics" => Dict(
        "accuracy" => 0.95,
        "loss" => 0.15,
        "valAccuracy" => 0.93,
        "valLoss" => 0.18
    )
)

toon_str = TOON.encode(metadata)
println(toon_str)
```

## Database Export

### Query Results

```julia
using ToonFormat

# Simulated database query results
query_results = [
    Dict("id" => 1, "name" => "Product A", "price" => 29.99, "stock" => 100),
    Dict("id" => 2, "name" => "Product B", "price" => 49.99, "stock" => 50),
    Dict("id" => 3, "name" => "Product C", "price" => 19.99, "stock" => 200)
]

# Export with pipe delimiter (database-style)
options = TOON.EncodeOptions(delimiter=TOON.PIPE)
toon_str = TOON.encode(Dict("products" => query_results), options=options)
println(toon_str)
# products[3|]{id|name|price|stock}:
#   1|Product A|29.99|100
#   2|Product B|49.99|50
#   3|Product C|19.99|200
```

## LLM Context

### Prompt with Data

```julia
using ToonFormat

# Prepare data for LLM prompt
context_data = Dict(
    "user" => Dict(
        "name" => "Alice",
        "preferences" => ["sci-fi", "mystery"],
        "readBooks" => 42
    ),
    "recommendations" => [
        Dict("title" => "Dune", "author" => "Frank Herbert", "genre" => "sci-fi"),
        Dict("title" => "Foundation", "author" => "Isaac Asimov", "genre" => "sci-fi"),
        Dict("title" => "The Martian", "author" => "Andy Weir", "genre" => "sci-fi")
    ]
)

# Encode for LLM context
toon_str = TOON.encode(context_data)

# Build prompt
prompt = """
Based on the following user data, suggest additional books:

$toon_str

Please provide 3 more recommendations.
"""

println(prompt)
```

## Testing

### Test Fixtures

```julia
using ToonFormat, Test

# Define test fixtures in TOON format
fixtures_toon = """
users[3]{id,name,role}:
  1,Alice,admin
  2,Bob,user
  3,Charlie,user
settings:
  theme: dark
  notifications: true
"""

# Load fixtures
fixtures = TOON.decode(fixtures_toon)

# Use in tests
@testset "User Tests" begin
    users = fixtures["users"]
    @test length(users) == 3
    @test users[1]["name"] == "Alice"
    @test users[1]["role"] == "admin"
end
```

## Data Migration

### Format Conversion

```julia
using ToonFormat, JSON

# Convert JSON to TOON
function json_to_toon(json_file, toon_file; options=TOON.EncodeOptions())
    data = JSON.parsefile(json_file)
    toon_str = TOON.encode(data, options=options)
    write(toon_file, toon_str)
end

# Convert TOON to JSON
function toon_to_json(toon_file, json_file)
    toon_str = read(toon_file, String)
    data = TOON.decode(toon_str)
    json_str = JSON.json(data, 2)  # Pretty print with 2-space indent
    write(json_file, json_str)
end

# Usage
json_to_toon("data.json", "data.toon", options=TOON.EncodeOptions(delimiter=TOON.TAB))
toon_to_json("data.toon", "data_converted.json")
```

## Next Steps

- Review [API Reference](api.md) for complete function documentation
- Check [Compliance](compliance.md) for specification details
- See [User Guide](guide/encoding.md) for detailed explanations
