module MMS_Example

using EventSimulation
using Random
using Test
using Future: randjump

# Objectives of the example:
# * show how SimQueue and SimResource objects can be used
# * show that SimQueue gives a fine grained control than SimResource
#   but is more expensive (actually SimResource use is a hack)
# * show how MersenneTwister with randjump can be used to control RNG streams

# exact formula for M/M/s queue
function run_mms_exact(ar, sr, s)
    ρ = ar/sr
    P₀= 1 / (ρ^s/(factorial(s)*(1-ρ/s)) +
             sum(ρ^n/factorial(n) for n in 0:(s-1)))
    (ρ+(ρ^(s+1)/(factorial(s-1)*(s-ρ)^2))*P₀)/ar
end

# hardcoded M/M/1 queue
function run_mm1_fast(until, ar, sr, seed)
    start_time = time_ns()
    ma = MersenneTwister(seed)
    ms = randjump(ma, big(10)^20)
    queue = Vector{Float64}()
    nextArrival = randexp(ma) / ar
    nextDeparture = Inf
    totalWait = 0.0
    totalCount = 0
    now = 0.0
    msg = String[]
    while now < until
        if nextArrival < nextDeparture
            now = nextArrival
            if now <= until
                push!(msg, "A $now")
            end
            if isempty(queue)
                nextDeparture = nextArrival + randexp(ms) / sr
            end
            push!(queue, nextArrival)
            nextArrival += randexp(ma) / ar
        else
            now = nextDeparture
            if now <= until
                push!(msg, "D $now")
                totalWait += nextDeparture - popfirst!(queue)
                totalCount += 1
            end
            if isempty(queue)
                nextDeparture = Inf
            else
                nextDeparture += randexp(ms) / sr
            end
        end
    end
    println("MM1 fast time: ", (time_ns()-start_time)/10^9)
    return totalWait/totalCount, totalCount, msg
end

# Implementation of M/M/s queue using SimQueue
mutable struct StateQ <: AbstractState
    ar::Float64
    sr::Float64
    q::SimQueue{Float64}
    tcust::Int
    tin::Float64
    ma::MersenneTwister
    ms::MersenneTwister
    msg::Vector{String}
    function StateQ(ar, sr)
        ma = MersenneTwister(1)
        ms = randjump(ma, big(10)^20)
        new(Float64(ar), Float64(sr), SimQueue{Float64}(),
            0, 0.0, ma, ms, String[])
    end
end

function arrivalQ!(s::Scheduler)
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
    start_time = time_ns()
    s = Scheduler(StateQ(ar, sr))
    repeat_register!(s, arrivalQ!, x -> randexp(x.state.ma) / x.state.ar)
    for i in 1:count
        request!(s, s.state.q, startserviceQ!)
    end
    go!(s, until)
    println("MM$count queue time: ", (time_ns() - start_time)/10^9)
    return s.state.tin/s.state.tcust, s.state.tcust, s.state.msg 
end

# Implementation of M/M/s queue using SimResource
# Notice that if s>1 we have no control of arrival vs departure order
mutable struct StateR <: AbstractState
    ar::Float64
    sr::Float64
    r::SimResource{Int}
    ars::Vector{Float64}
    tcust::Int
    tin::Float64
    ma::MersenneTwister
    ms::MersenneTwister
    msg::Vector{String}
    function StateR(ar, sr)
        ma = MersenneTwister(1)
        ms = randjump(ma, big(10)^20)
        new(Float64(ar), Float64(sr), SimResource{Int}(),
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
    s.state.tin += s.now - popfirst!(s.state.ars)
    push!(s.state.msg, "D $(s.now)")
    request!(s, s.state.r, 1, startserviceR!)
end

function run_mms_resource(until, ar, sr, count)
    start_time = time_ns()
    s = Scheduler(StateR(ar, sr))
    register!(s, arrivalR!, randexp(s.state.ma) / s.state.ar)
    for i in 1:count
        request!(s, s.state.r, 1, startserviceR!)
    end
    go!(s, until)
    println("MM$count resource time: ", (time_ns()-start_time)/10^9)
    # have to handle shortcomming of resource
    return (count == 1 ? s.state.tin/s.state.tcust : NaN,
            s.state.tcust, s.state.msg)
end

@testset "Test of M/M/1 queue" begin
    t_f = run_mm1_fast(100_000, 0.8, 1.4, 1)
    t_q = run_mms_queue(100_000, 0.8, 1.4, 1)
    t_r = run_mms_resource(100_000, 0.8, 1.4, 1)
    t_x = run_mms_exact(0.8, 1.4, 1)

    @test t_f == t_q == t_r
    @test isapprox(t_x, t_r[1], atol=0.1)
end

@testset "Test of M/M/2 queue" begin
    t2_q = run_mms_queue(100_000, 0.8, 0.7, 2)
    t2_r = run_mms_resource(100_000, 0.8, 0.7, 2)
    t2_x = run_mms_exact(0.8, 0.7, 2)

    @test t2_q[2:3] == t2_r[2:3]
    @test isapprox(t2_x, t2_q[1], atol=0.1)
end

@testset "Test of M/M/5 queue" begin
    t5_q = run_mms_queue(100_000, 0.8, 0.2, 5)
    t5_r = run_mms_resource(100_000, 0.8, 0.2, 5)
    t5_x = run_mms_exact(0.8, 0.2, 5)

    @test t5_q[2:3] == t5_r[2:3]
    @test isapprox(t5_x, t5_q[1], atol=0.2)
end

end # module

