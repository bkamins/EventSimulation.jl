using EventSimulation
using Base.Test

# exact formula for M/M/s queue
function run_mms_exact(ar, sr, s)
    ρ = ar/sr
    P₀= 1 / (ρ^s/(factorial(s)*(1-ρ/s)) +
             sum(ρ^n/factorial(n) for n in 0:(s-1)))
    (ρ+(ρ^(s+1)/(factorial(s-1)*(s-ρ)^2))*P₀)/ar
end

# hardcoded M/M/1 queue
function run_mm1_fast(until, ar, sr, seed)
    tic()
    queue = Vector{Float64}()
    nextArrival = 0.0
    nextDeparture = Inf
    totalWait = 0.0
    totalCount = 0
    now = 0.0
    ma, ms = randjump(MersenneTwister(seed), 2)
    msg = String[]
    while now < until
        if nextArrival < nextDeparture
            now = nextArrival
            push!(msg, "A $now")
            if isempty(queue)
                nextDeparture = nextArrival + randexp(ms) / sr
            end
            push!(queue, nextArrival)
            nextArrival += randexp(ma) / ar
        else
            now = nextDeparture
            push!(msg, "D $now")
            totalWait += nextDeparture - shift!(queue)
            totalCount += 1
            if isempty(queue)
                nextDeparture = Inf
            else
                nextDeparture += randexp(ms) / sr
            end
        end
    end
    println("MM1 fast time: ", toq())
    return totalWait/totalCount, totalCount, msg
end

# Implementation of M/M/s queue using Queue
type StateQ <: AbstractState
    ar::Float64
    sr::Float64
    q::Queue{Float64}
    tcust::Int
    tin::Float64
    ma::MersenneTwister
    ms::MersenneTwister
    msg::Vector{String}
    function StateQ(ar, sr)
        ma, ms = randjump(MersenneTwister(1), 2)
        new(Float64(ar), Float64(sr), Queue{Float64}(),
            0, 0.0, ma, ms, String[])
    end
end

function arrivalQ!(s::Scheduler)
    register!(s, arrivalQ!, randexp(s.state.ma) / s.state.ar)
    push!(s.state.msg, "A $(s.now)")
    provide!(s, s.state.q, s.now)
end

function startserviceQ!(s::Scheduler, a::Float64)
    register!(s, x -> endserviceQ!(x, a) , randexp(s.state.ms) / s.state.sr)
end

function endserviceQ!(s::Scheduler, a::Float64)
    s.state.tcust += 1
    s.state.tin += s.now - a
    push!(s.state.msg, "D $(s.now)")
    request!(s, s.state.q, startserviceQ!)
end

function run_mms_queue(until, ar, sr, count)
    tic()
    s = Scheduler(StateQ(ar, sr))
    register!(s, arrivalQ!)
    for i in 1:count
        request!(s, s.state.q, startserviceQ!)
    end
    go!(s, until)
    println("MM$count queue time: ", toq())
    return s.state.tin/s.state.tcust, s.state.tcust, s.state.msg 
end

# Implementation of M/M/s queue using Resource
# Notice that if s>1 we have no control of arrival vs departure order
type StateR <: AbstractState
    ar::Float64
    sr::Float64
    r::Resource{Int}
    ars::Vector{Float64}
    tcust::Int
    tin::Float64
    ma::MersenneTwister
    ms::MersenneTwister
    msg::Vector{String}
    function StateR(ar, sr)
        ma, ms = randjump(MersenneTwister(1), 2)
        new(Float64(ar), Float64(sr), Resource{Int}(),
            Vector{Float64}(), 0, 0.0, ma, ms, String[])
    end
end

function arrivalR!(s::Scheduler)
    register!(s, arrivalR!, randexp(s.state.ma) / s.state.ar)
    push!(s.state.ars, s.now)
    push!(s.state.msg, "A $(s.now)")
    provide!(s, s.state.r, 1)
end

function startserviceR!(s::Scheduler)
    register!(s, endserviceR!, randexp(s.state.ms) / s.state.sr)
end

function endserviceR!(s::Scheduler)
    s.state.tcust += 1
    # use s.state.tin only for count==1, otherwise it is inexact
    # as customer ordering migh have changed during the service
    s.state.tin += s.now - shift!(s.state.ars)
    push!(s.state.msg, "D $(s.now)")
    request!(s, s.state.r, 1, startserviceR!)
end

function run_mms_resource(until, ar, sr, count)
    tic()
    s = Scheduler(StateR(ar, sr))
    register!(s, arrivalR!)
    for i in 1:count
        request!(s, s.state.r, 1, startserviceR!)
    end
    go!(s, until)
    println("MM$count resource time: ", toq())
    # have to handle shortcomming of resource
    return (count == 1 ? s.state.tin/s.state.tcust : NaN,
            s.state.tcust, s.state.msg)
end

println("Test of M/M/1 queue")
t_f = run_mm1_fast(100_000, 0.8, 1.4, 1)
t_q = run_mms_queue(100_000, 0.8, 1.4, 1)
t_r = run_mms_resource(100_000, 0.8, 1.4, 1)
t_x = run_mms_exact(0.8, 1.4, 1)

@test t_f == t_q == t_r
@test isapprox(t_x, t_r[1], atol=0.1)

println("Test of M/M/2 queue")
t2_q = run_mms_queue(100_000, 0.8, 0.7, 2)
t2_r = run_mms_resource(100_000, 0.8, 0.7, 2)
t2_x = run_mms_exact(0.8, 0.7, 2)

@test t2_q[2:3] == t2_r[2:3]
@test isapprox(t2_x, t2_q[1], atol=0.1)

println("Test of M/M/5 queue")
t5_q = run_mms_queue(100_000, 0.8, 0.2, 5)
t5_r = run_mms_resource(100_000, 0.8, 0.2, 5)
t5_x = run_mms_exact(0.8, 0.2, 5)

@test t5_q[2:3] == t5_r[2:3]
@test isapprox(t5_x, t5_q[1], atol=0.2)

