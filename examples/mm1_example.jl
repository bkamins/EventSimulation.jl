module MM1_Example

using EventSimulation
using Random
using Test

# Objectives of the example:
# * show basic use of monitor function

mutable struct MMQueue <: AbstractState
    ar::Float64 # arrival rate
    sr::Float64 # service rate
    len::Int    # queue length
    busy::Bool  # is server busy?
    load_data::Dict{Int, Float64} # store for monitor data
end

# here we accumulate information about queue lengths and periods
function monitor(s, Δ)
    ld = s.state.load_data
    load = s.state.len + s.state.busy
    if haskey(ld, load)
        ld[load] += Δ
    else
        ld[load] = Δ
    end
end

# customer arrival event
function arrival(s)
    if s.state.busy # server is working?
        s.state.len += 1
    else
        s.state.busy = true
        register!(s, leave, randexp()/s.state.sr)
    end
end

# customer leave the system event
function leave(s)
    if s.state.len > 0 # any customers waiting?
        s.state.len -= 1
        register!(s, leave, randexp()/s.state.sr)
    else
        s.state.busy = false
    end
end

function run(ar, sr)
    q = MMQueue(ar, sr, 0, false, Dict{Int, Float64}())
    s = Scheduler(q, Float64, monitor)
    repeat_register!(s, arrival, x -> randexp()/ar)
    go!(s, 1_000_000)
    ks = sort(collect(keys(q.load_data)))
    s = sum(values(q.load_data))
    ρ = ar / sr
    maxdiff = 0.0 # calculated for accuracy testing purposes
    for k in ks
        em = round(q.load_data[k]/s, digits=4)
        th = round((1-ρ)*ρ^k, digits=4)
        maxdiff = max(maxdiff, abs(em-th))
        println("$k\t=> ", rpad(em,6), "\t", th)
    end
    return(maxdiff)
end

@testset "Test of M/M/1 queue with monitor" begin
    @test run(1.5, 3.5) < 0.005
end

end # module

