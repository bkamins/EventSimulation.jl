using Documenter
using EventSimulation

makedocs()

deploydocs(repo = "github.com/bkamins/EventSimulation.jl.git",
           target = "build", deps = nothing, make = nothing)
