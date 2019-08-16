using EventSimulation
using Distributions
using StructArrays

mutable struct Customer
    tin::Float64
    tout::Float64
end

mutable struct Server
    queue::SimQueue{Customer}
    customer::Union{Customer, Nothing}
end

mutable struct State{T1, T2} <: AbstractState
    servers::T1
    left_customers::T2
    shortest::Bool
    ad::Exponential{Float64}
    sd::Exponential{Float64}
end

function arrival(s)
    if s.state.shortest
        qlen = [length(q.queue) for q in s.state.servers.queue]
        idleserver = isnothing.(s.state.servers.customer)
        i = argmin(qlen .- idleserver)
        q = s.state.servers.queue[i]
    else
        q = rand(s.state.servers.queue)
    end
    provide!(s, q, Customer(s.now, NaN))
end

function request_service(server)
    function start_service(s, customer)
        @assert isnothing(server.customer)
        server.customer = customer
        register!(s, finish_service, rand(s.state.sd))
    end

    function finish_service(s)
        server.customer.tout = s.now
        push!(s.state.left_customers, server.customer)
        server.customer = nothing
        request!(s, server.queue, request_service(server))
    end
    start_service
end

function runsim(ar::Number, sr::Number, n::Integer, shortest::Bool)
    servers = [Server(SimQueue{Customer}(), nothing) for i in 1:n]
    ss = State(StructArray(servers), StructArray(Customer[]),
               shortest, Exponential(1/ar), Exponential(1/sr))
    s = Scheduler(ss)
    repeat_register!(s, arrival, x -> rand(ss.ad))
    for server in ss.servers
        request!(s, server.queue, request_service(server))
    end
    go!(s, 1_000_000)
    lc = s.state.left_customers
    mean(lc.tout) - mean(lc.tin)
end

runsim(1, 0.4, 3, true)
runsim(1, 0.4, 3, false)
