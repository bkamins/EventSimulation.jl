# Experiment 4.1 from:
# C.-H. Chen, L.H. Lee: Stochastic Simulation Optimization, World Scientific, 2011

using Random
using EventSimulation
using Distributions

mutable struct SeqQueue <: AbstractState
    q1::SimResource{Int}
    q2::SimResource{Int}
    arrive::Vector{Float64}
    depart::Vector{Float64}
end

arrival(s) = (provide!(s, s.state.q1, 1); push!(s.state.arrive, s.now))
stage1(s) = register!(s, leave1, rand(Uniform(1, 39)))
leave1(s) = (provide!(s, s.state.q2, 1); request!(s, s.state.q1, 1, stage1))
stage2(s) = register!(s, leave2, rand(Uniform(5, 45)))
leave2(s) = (push!(s.state.depart, s.now); request!(s, s.state.q2, 1, stage2))

function exec(n1, n2)
    state = SeqQueue(SimResource{Int}(), SimResource{Int}(), Float64[], Float64[])
    s = Scheduler(state)
    repeat_register!(s, arrival, (x -> length(s.state.arrive) < 100 ? randexp() : nothing))
    foreach(i -> request!(s, state.q1, 1, stage1), 1:n1)
    foreach(i -> request!(s, state.q2, 1, stage2), 1:n2)
    go!(s)
    @assert length(state.depart) == length(state.arrive)
    return mean(state.depart) - mean(state.arrive)
end

for i in 1:10
    v = mean(exec(10+i, 21-i) for j in 1:2048)
    println((10+i, 21-i),":\t", v)
end
