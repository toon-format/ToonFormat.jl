#!/usr/bin/env julia

"""
DEPRECATED: This script is no longer needed.

The TOON specification test fixtures are now included via Git submodule.

To get the fixtures, use one of these approaches:

1. Clone with submodules:
   git clone --recurse-submodules https://github.com/toon-format/ToonFormat.jl.git

2. Initialize submodule after cloning:
   git submodule update --init --recursive

3. Update to latest spec version:
   git submodule update --remote test/spec

The fixtures are located at: test/spec/tests/fixtures/
"""

@warn """
DEPRECATED: download_fixtures.jl is no longer needed.

Fixtures are now included via Git submodule at test/spec/

To initialize the submodule, run:
    git submodule update --init --recursive

See test/spec/tests/fixtures/ for the official fixtures.
"""

println()
println("This script is deprecated. Use the Git submodule instead:")
println()
println("  git submodule update --init --recursive")
println()
println("Fixtures location: test/spec/tests/fixtures/")
