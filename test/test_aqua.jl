# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON
using Aqua

@testset "Aqua.jl Quality Assurance" begin
    # Run all Aqua tests with custom configuration
    Aqua.test_all(
        TOON;
        # Ambiguities can be noisy and sometimes unavoidable
        ambiguities = true,
        # Check for unbound type parameters
        unbound_args = true,
        # Check for undefined exports
        undefined_exports = true,
        # Check project structure (Project.toml, test setup, etc.)
        project_extras = true,
        # Check for stale dependencies
        stale_deps = true,
        # Check for missing dependencies
        deps_compat = true,
        # Check for piracies (type piracy is bad practice)
        piracies = true,
        # Check for persistent tasks
        persistent_tasks = true,
    )
    
    @testset "Method Ambiguities" begin
        # Test for method ambiguities more explicitly
        # This helps catch potential dispatch issues
        Aqua.test_ambiguities(TOON)
    end
    
    @testset "Unbound Type Parameters" begin
        # Ensure no functions have unbound type parameters
        Aqua.test_unbound_args(TOON)
    end
    
    @testset "Undefined Exports" begin
        # Check that all exported names are actually defined
        Aqua.test_undefined_exports(TOON)
    end
    
    @testset "Project Structure" begin
        # Verify Project.toml and test dependencies are properly configured
        Aqua.test_project_extras(TOON)
    end
    
    @testset "Stale Dependencies" begin
        # Check for dependencies listed but not used
        Aqua.test_stale_deps(TOON)
    end
    
    @testset "Dependency Compatibility" begin
        # Ensure all dependencies have [compat] entries
        Aqua.test_deps_compat(TOON)
    end
    
    @testset "Type Piracies" begin
        # Check for type piracy (extending methods on types you don't own)
        Aqua.test_piracies(TOON)
    end
    
    @testset "Persistent Tasks" begin
        # Check for tasks that might not be cleaned up properly
        Aqua.test_persistent_tasks(TOON)
    end
end
