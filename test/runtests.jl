using EventSimulation
using Test
using Random

tests = ["core",
         "prioritytime",
         "queue",
         "resource",
         "../examples/mms_example",
         "../examples/mm1_example",
        ]

println("Running tests:")

for t in tests
    tfile = string(t, ".jl")
    println(" * $(tfile) ...")
    include(tfile)
end
