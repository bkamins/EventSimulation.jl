using EventSimulation
using Distributions

type Customer
    name::String
    arrival_time::Float64
    renege_a::Action{Float64}

    function Customer(name, arrival_time)
        x = new()
        x.name = name
        x.arrival_time = arrival_time
        return x
    end
end

type BankState <: AbstractState
    all_cust::Int
    n::Int
    reneged_count::Int
    arrival::Exponential{Float64}
    patience::Uniform{Float64}
    cashing::Exponential{Float64}
    counter::Queue{Customer}
    report::Bool
end

function source(s::Scheduler)
    s.state.n += 1
    c = Customer(string("Customer", s.state.n), s.now)
    s.state.report && @printf("%6.4f %s: Here I am\n", s.now, c.name)
    provide!(s, s.state.counter, c)
    c.renege_a = register!(s, x -> renege(x, c), rand(s.state.patience))
    if s.state.n < s.state.all_cust
        register!(s, source, rand(s.state.arrival))
    end
end

function renege(s, c)
    s.state.report && @printf("%6.4f %s: RENEGED after %6.4f\n",
                              s.now, c.name, s.now-c.arrival_time)
    s.state.reneged_count += 1
    withdraw!(s.state.counter, c) || error("should not happen in renege")
end

function serve(s, c)
    s.state.report && @printf("%6.4f %s: waited %6.4f\n",
                              s.now, c.name, s.now-c.arrival_time)
    interrupt!(s, c.renege_a) || error("should not happen in serve")
    register!(s, x -> finish(x, c), rand(s.state.cashing))
end

function finish(s, c)
    s.state.report && @printf("%6.4f %s: Finished\n", s.now, c.name)
    request!(s, s.state.counter, serve)
end

function run(ccount, report)
    bs = BankState(ccount, 0, 0, Exponential(10.0),
                   Uniform(1.0, 3.0), Exponential(12.0),
                   Queue{Customer}(), report)
    report && println("Bank renege")
    s = Scheduler(bs)
    request!(s, bs.counter, serve)
    source(s)
    go!(s, Inf)
    println("Renege probability: ", bs.reneged_count / bs.all_cust)
end

srand(1)
@time run(10, true)
@time run(1_000_000, false)

