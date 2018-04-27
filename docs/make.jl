using Documenter
using EventSimulation

makedocs()

deploydocs(repo = "github.com/bkamins/EventSimulation.jl.git",
           osname = "osx", julia = "nightly")
