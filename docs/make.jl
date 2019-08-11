using EventSimulation
using Documenter

makedocs()

deploydocs(repo = "github.com/bkamins/EventSimulation.jl.git",
           target = "build", deps = nothing, make = nothing)
