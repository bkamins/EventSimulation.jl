using EventSimulation
using Distributions
using Statistics
using Random
using Test

mutable struct MMQueue <: AbstractState
    sp::Exponential{Float64} # service rate
    qlen::Int   # queue length
    busy::Bool  # is server busy?
    arrival_times::Vector{Float64} # when customers arrived
    departure_times::Vector{Float64} # when customers left
end

# customer arrival event
function arrival(s)
    push!(s.state.arrival_times, s.now)
    if s.state.busy # server is working?
        s.state.qlen += 1
    else
        s.state.busy = true
        register!(s, leave, rand(s.state.sp))
    end
end

# customer leave the system event
function leave(s)
    push!(s.state.departure_times, s.now)
    if s.state.qlen > 0 # any customers waiting?
        s.state.qlen -= 1
        register!(s, leave, rand(s.state.sp))
    else
        s.state.busy = false
    end
end

function run(ar, sr)
    q = MMQueue(Exponential(1 / sr), 0, false, Float64[], Float64[])
    s = Scheduler(q, Float64)
    repeat_register!(s, arrival, x -> rand(Exponential(1/ar)))
    go!(s, 1_000_000)
    mean(d-a for (a,d) in zip(s.state.arrival_times, s.state.departure_times))
end

Random.seed!(1)
for ar in 0.1:0.1:0.9
    @test abs(run(ar, 1.0)*(1-ar)-1) < 0.03
end
