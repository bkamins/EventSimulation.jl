using EventSimulation
using Documenter

makedocs(sitename="EventSimulation.jl")

deploydocs(repo = "github.com/bkamins/EventSimulation.jl.git",
           target = "build", deps = nothing, make = nothing)
