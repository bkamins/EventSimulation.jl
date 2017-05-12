using EventSimulation
using Base.Test

type Queue <: AbstractState
    ar::Float64
    sr::Float64
    len::Int
    busy::Bool
    load_data::Dict{Int, Float64}
end

function monitor(s,Δ)
    ld = s.state.load_data
    load = s.state.len + s.state.busy
    if haskey(ld, load)
        ld[load] += Δ
    else
        ld[load] = Δ
    end
end

function arrival(s)
    if s.state.busy
        s.state.len += 1
    else
        s.state.busy = true
        register!(s, leave, randexp()/s.state.sr)
    end
end

function leave(s)
    if s.state.len > 0
        s.state.len -= 1
        register!(s, leave, randexp()/s.state.sr)
    else
        s.state.busy = false
    end
end

function run(ar, sr)
    q = Queue(ar, sr, 0, false, Dict{Int, Float64}())
    s = Scheduler(q, Float64, monitor)
    repeat_register!(s, arrival, x -> randexp()/ar)
    go!(s, 1_000_000)
    ks = sort(collect(keys(q.load_data)))
    s = sum(values(q.load_data))
    ρ = ar / sr
    maxdiff = 0.0
    for k in ks
        em = round(q.load_data[k]/s, 4)
        th = round((1-ρ)*ρ^k, 4)
        maxdiff = max(maxdiff, abs(em-th))
        println("$k\t=> ", rpad(em,6), "\t", th)
    end
    return(maxdiff)
end

@test run(1.5, 3.5) < 0.005

