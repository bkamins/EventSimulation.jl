using EventSimulation
using Distributions

mutable struct Customer
    tin::Float64
    tout::Float64
end

mutable struct Server
    id::Int
    customer::Union{Customer, Nothing}
end

mutable struct State <: AbstractState
    queues::Vector{SimQueue{Customer}}
    servers::Vector{Server}
    left_customers::Vector{Customer}
    shortest::Bool
    ad::Exponential{Float64}
    sd::Exponential{Float64}
end

function arrival(s)
    if s.state.shortest
        qlen = length.(getproperty.(s.state.queues, :queue))
        inserver = .!isnothing.(getproperty.(s.state.servers, :customer))
        i = argmin(qlen .+ inserver)
        q = s.state.queues[i]
    else
        q = rand(s.state.queues)
    end
    provide!(s, q, Customer(s.now, NaN))
end

function request_service(s, i)
    function start_service(s, customer)
        @assert isnothing(server.customer)
        server.customer = customer
        register!(s, finish_service, rand(s.state.sd))
    end

    function finish_service(s)
        server.customer.tout = s.now
        push!(s.state.left_customers, server.customer)
        server.customer = nothing
        request!(s, s.state.queues[i], request_service(s, i))
    end
    server = s.state.servers[i]
    start_service
end

function runsim(ar::Number, sr::Number, n::Integer, shortest::Bool)
    ss = State([SimQueue{Customer}() for _ in 1:n],
               [Server(i, nothing) for i in 1:n],
               Customer[], shortest, Exponential(1/ar), Exponential(1/sr))
    s = Scheduler(ss)
    repeat_register!(s, arrival, x -> rand(ss.ad))
    for (i, q) in enumerate(ss.queues)
        request!(s, q, request_service(s, i))
    end
    go!(s, 1_000_000)
    lc = s.state.left_customers
    mean(@. getproperty(lc, :tout) - getproperty(lc, :tin))
end

runsim(1, 0.4, 3, true)
runsim(1, 0.4, 3, false)
