# This is a rewrite of SimJulia.jl example of
# Ross S. (2012): Simulation, 5th edition, Section 7.7, p. 124-126

using EventSimulation
using Distributions
using Random

const RUNS = 5
const N = 10
const S = 3
const LAMBDA = 100
const MU = 1
const SEED = 150

const F = Exponential(LAMBDA)
const G = Exponential(MU)

mutable struct RepairState <: AbstractState
    spare::Int
    repair::Int
end

function breakdown(s)
    if s.state.spare == 0
        println("At time $(s.now): No more spares!")
        terminate!(s)
    else
        s.state.spare -= 1
        register!(s, breakdown, rand(F))
        s.state.repair += 1
        s.state.repair == 1 && register!(s, repaired, rand(G))
    end
end

function repaired(s)
    s.state.spare += 1
    s.state.repair -= 1
    s.state.repair > 0 && register!(s, repaired, rand(G))
end

function exec()
    state = RepairState(S, 0)
    s = Scheduler(state)
    for i in 1:N
        register!(s, breakdown, rand(F))
    end
    go!(s)
    s.now
end

Random.seed!(SEED)
results = Float64[]
for i in 1:RUNS push!(results, exec()) end
println("Average crash time: ", sum(results)/RUNS)
