using EventSimulation
using Distributions
using Statistics
using DataFrames
using PyPlot

mutable struct MMQueue{T<:Distribution} <: AbstractState
    sp::T # service rate
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

function run(ar::Distribution, sr::Distribution)
    q = MMQueue(sr, 0, false, Float64[], Float64[])
    s = Scheduler(q, Float64)
    repeat_register!(s, arrival, x -> rand(ar))
    go!(s, 1_000_000)
    mean(d-a for (a,d) in zip(s.state.arrival_times, s.state.departure_times))
end

results = DataFrame()
sr = 1.0
sre = Exponential(1/sr)
sru = Uniform(0, 2/sr)
for ar in 0.1:0.1:0.9
    are = Exponential(1/ar)
    aru = Uniform(0, 2/ar)
    push!(results, (ar=ar,
                    sojourn_ee=run(are, sre),
                    sojourn_ue=run(aru, sre),
                    sojourn_eu=run(are, sru),
                    sojourn_uu=run(aru, sru),
                    theoretical=1/(1-ar/sr)/sr))
end

plot(results.ar, Matrix(results[:, 2:end]))
legend(names(results)[2:end])
