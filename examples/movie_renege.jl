using EventSimulation
using Distributions

# Objectives of the example:
# * show how SimQueue object can be used
# * filter! as withdraw! using predicate

mutable struct Customer
    movie::Int   # which movie to attend
    tickets::Int # how many tickets
end

mutable struct Cinema <: AbstractState
    movies::Vector{String}     # names of movies
    available::Vector{Int}     # tickets left
    sold_time::Vector{Float64} # time when tickets were sold out
    renege_count::Vector{Int}  # number of people that left the queue
    counter::SimQueue{Customer}   # queue to counter
end

function arrival(s::Scheduler)
    c = Customer(rand(1:3), rand(1:6))
    if s.state.available[c.movie] > 1   # we do not sell last ticket
        provide!(s, s.state.counter, c)
    end
end

function buy_ticket(s, c)
    if s.state.available[c.movie] < c.tickets
        register!(s, leave_counter, 0.5) # arguing
    else
        s.state.available[c.movie] -= c.tickets

        # collect stats - tickets sold-out
        if s.state.available[c.movie] < 2 # we do not sell last ticket
            s.state.sold_time[c.movie] = s.now
            s.state.renege_count[c.movie] = count(x -> x.movie == c.movie,
                                                  s.state.counter.queue)
            # customers leave queue
            filter!(x -> x.movie != c.movie, s.state.counter.queue)
        end
        register!(s, leave_counter, 1.0) # buying
    end
    maximum(s.state.available) < 2 && terminate!(s) # no tickets to sell
end

function leave_counter(s)
    request!(s, s.state.counter, buy_ticket)
end

function run(report::Bool)
    ms = ["Python Unchained", "Kill Process", "Pulp Implementation"]
    cinema = Cinema(ms, [50, 50, 50], [NaN, NaN, NaN],
                    [0, 0, 0], SimQueue{Customer}())
    s = Scheduler(cinema)
    request!(s, cinema.counter, buy_ticket)
    repeat_register!(s, arrival, x -> rand(Exponential(0.5)))
    go!(s, Inf)
    if report
        for i in 1:3
            println("Movie ", cinema.movies[i], " sold out ",
                    round(cinema.sold_time[i], 4),
                    " minutes after ticket counter opening.\n",
                    "  Number of people leaving queue when film sold out: ",
                    cinema.renege_count[i], ".")
        end
    end
    [cinema.sold_time; cinema.renege_count]
end

function reprun(reps, report::Bool, stats::Bool)
    res = hcat([run(report) for i in 1:reps]...)
    stats || return
    println("\tmean\tsd\tmin\tmax")

    # total time to terminate
    tt = maximum(view(res, 1:3, :), 1)
    @printf("finish\t%6.3f\t%5.3f\t%6.3f\t%6.3f\n", mean(tt), std(tt),
            minimum(tt), maximum(tt))

    # time to terminate per movie
    for i in 1:3
        v = view(res, i, :)
        @printf("mv %d\t%6.3f\t%5.3f\t%6.3f\t%6.3f\n", i, mean(v), std(v),
                minimum(v), maximum(v))
    end
    
    # reneged customers per movie
    for i in 1:3
        v = view(res, i+3, :)
        @printf("cr %d\t%6.3f\t%5.3f\t%6.3f\t%6.3f\n", i, mean(v), std(v),
                minimum(v), maximum(v))
    end
end

@time reprun(10_000, false, true)
@time reprun(10_000, false, true)
