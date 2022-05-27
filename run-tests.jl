#!/usr/bin/env julia

# Runs tests of the package

using Pkg

Pkg.activate(@__DIR__)
Pkg.test("JuliaSub")
