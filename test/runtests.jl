using EventSimulation
using Base.Test

tests = ["core",
        ]

println("Running tests:")

for t in tests
    tfile = string(t, ".jl")
    println(" * $(tfile) ...")
    include(tfile)
end

