# [EventSimulation Tutorial](@id tutorial)

## Installation

In REPL run `Pkg.add("EventSimulation")` to install the package and next
`using EventSimulation` to start using it.

## First simulation

This is a bare minimum simulation using EventSimulation:

```
using EventSimulation

function arrival(s)
    t = s.now
    println("Arrived at ", s.now)
    register!(s, x -> println("Left at $(x.now) that arrived at $t"), 1.5)
end

s = Scheduler()
for t in 1.0:5.0
    register!(s, arrival, t)
end

go!(s)
```

In this example five customers arrive at times 1, 2, ..., 5 and stay in the
system for 1.5 time units. Observe that in `arrival` we use a closure to define
anonymous function that is registered. In its body `x.now` will be taken from
the state of the scheduler when the anonymous function is invoked but `t` is
fixed in enclosing scope of `arrival` function as the time of the arrival.

**Exercise**: *Test what happens if you replace `$t` with `$(s.now)` in the
anonymous function. What is the reason of this behavior?*

When using EventSimulation working with closures is often the simplest way
to develop a simulation so it is important that you understand this example.

## Defining infinite source of events

Now we add an infinite stream of customers arriving to the system:

```
using EventSimulation

function arrival(s)
    t = s.now
    println("Arrived at ", s.now)
    register!(s, x -> println("Left at $(x.now) that arrived at $t"), 1.5)
end

s = Scheduler()
repeat_register!(s, arrival, x -> 1.0)

go!(s, 7)

```

In this example we show how `arrival` function can be scheduled to be repeatedly
put into event queue in time deltas defined by anonymous function `x -> 1.0`.

Aslo observe that we have passed second argument `7` to function `go!` which
will force unconditional termination of the simulation after this moment.

**Exercise**: *Think what would happen if the termination time would be omitted in
the expression `go!(s, 7)`. How you could use function `terminate!` inside
definition of `arrival` to get a similar effect. What would be the difference?*

## Defining custom simulation state

Now let us add a simple counter of number of customers in the system:

```
using EventSimulation

mutable struct CounterState <: AbstractState
    count::Int
end

function arrival(s)
    function departure(x)
        x.state.count -= 1
        println("Left at $(x.now) that arrived at $t and left ",
                x.state.count, " other customers")
    end

    t = s.now
    println("Arrived at ", s.now, " and met ", s.state.count, " other customers")
    register!(s, departure, 1.0)
    s.state.count += 1
end

s = Scheduler(CounterState(0))

srand(1)
repeat_register!(s, arrival, x -> rand())
go!(s, 10)
```

Observe that all functions in EventSimulation receive `Scheduler` as an argument
and therefore they have acces to current simulation time and simulation state.

Additionally we have changed customer arrival behavior to random.

**Exercise**: *Try changing customer's arrival rate to the exponential distribution
using `randexp` function. Next change time in system distribution to the
Gamma distribution. You can find it in `Distributions` package.*

## Monitoring simulation

Let us calculate how many customers are present in the above system using
custom `monitor`.

```
using EventSimulation

mutable struct CounterState <: AbstractState
    count::Int
    total_time::Float64
    customer_time::Float64
end

function arrival(s)
    register!(s, departure, 1.0)
    s.state.count += 1
end

function departure(s)
    s.state.count -= 1
end

function monitor(s, Δ)
    s.state.total_time += Δ
    s.state.customer_time += Δ * s.state.count
end

cs = CounterState(0, 0.0, 0.0)
s = Scheduler(cs, Float64, monitor)

srand(1)
repeat_register!(s, arrival, x -> rand())
go!(s, 100_000)
println("Average number of customers in a system is ",
        cs.customer_time/cs.total_time)
```

Observe that `monitor` usually will modify simulation state to gather the
simulation statistics. Other approaches could use global variables
or variables defined in closure of `monitor`, but using simulation state
is the recommended approach.

**Exercise**: *Think if the obtained result is in line with
[Little's law](https://en.wikipedia.org/wiki/Little%27s_law).
Try changing arrival rate and time in the system to check it. As a more
advanced exercise make `monitor` collect data only when simulation time
is greater or equal than 100 (i.e. discarding simulation burn-in period).*

## Introduction to resources
Now we will consider two streams of agents. Supplier provides one unit
of good every one unit of time. There are customers that arrive randomly
and want to buy a random amount of good. Maximally two customers can wait in the line.
```
using EventSimulation

mutable struct GoodState <: AbstractState
    good::SimResource{Float64}
end

function delivery(s)
    provide!(s, s.state.good, 1.0)
    print_with_color(:green, "Delivered 1.0 at ", s.now, "\n")
end

function customer(s)
    function leave(x)
        println("Left at ", x.now, " with quantity ", round(demand, 4))
    end
    demand = rand()
    print("Arrived at ", round(s.now, 4), " with demand ", round(demand, 4))
    if !request!(s, s.state.good, demand, leave)[1]
        print_with_color(:red, " but line was too long and left with nothing\n")
    else
        println(" and went into a queue")
    end
end

function balance(s)
    info("Amount of good in storage: ",
         round(s.state.good.quantity, 4), " at time ", s.now)
end

s = Scheduler(GoodState(SimResource{Float64}(max_requests=2)))

srand(1)
repeat_register!(s, delivery, x -> 1.0)
repeat_register!(s, customer, x -> rand())
repeat_register!(s, balance, x -> x.now == 0 ? 1.000001 : 1.0)
go!(s, 5)
```

Observe that fulfillment of pending requests by `SimResource` is immediate.
This means that the amount is passed to a request from the container before
the request event executed.

**Exercise**: *We have used a fixed value of `0.000001` as an increment over an integer
number to invoke `balance`. Rewrite the example using `PriorityTime` type in such a way
that `balance` is invoked at integer times but with priority low enough.*

## Infinite delta in `repeat_register!`

In general EventSimulation does not check the values passed to the engine in order
to maximize execution speed. The only exception is `interval` argument of
`repeat_register` function. If it returns a value that is not finite then the repeated
scheduling of events is interrupted. Here is a simple example

```
using EventSimulation

mutable struct Jumps <: AbstractState
    n::Int
end

jump(s) = s.state.n+=1
next(s) = s.now >= 1.0 ? NaN : rand()

function main()
    s = Scheduler(Jumps(0))
    repeat_register!(s, jump, next)
    go!(s)
    s.state.n
end

println(mean(main() for i in 1:10^6))
```

The above code implements a well known puzzle.
Assume that we have a bug that gets hungry every `rand()` time units and eats then.
Assume that the fist time it eats is 0.
What is the expected number of times it will it till time reaches 1.0?
Run the code to learn the answer (if you did not know the puzzle before).
Observe that returning `NaN` from `next` forces the simulation to stop.

## Bulk execution of events

EventSimulation allows you to plan execution of a batch of actions at the same time.
They can be either executed in a predefined order or in random order
(this example actually does not require DES, but is a MWE of `bulk_register!`).

```
using EventSimulation

mutable struct Airplane <: AbstractState
    free::Set{Int}
    ok::Bool
end

function sit(s, i)
    s.state.ok = i in s.state.free
    pop!(s.state.free, s.state.ok ? i : rand(s.state.free))
end

function main(n)
    s = Scheduler(Airplane(Set(1:n), false))
    tickets = randperm(n)
    tickets[1] = rand(1:n)
    bulk_register!(s, tickets, sit, 0.0)
    go!(s)
    s.state.ok
end

for n in [10, 50, 250]
    println(n, "\t", mean(main(n) for i in 1:10^4))
end
```

Another simple puzzle. We have an airplane with `n` seats and `n` customers.
Every customer has a ticket with seat number. It is represented by a vector `tickets`.
Customers enter the airplane in the order of the vector `tickets` and everyone tries to
sit on her own seat. Unfortunately `tickets[1] = rand(1:n)` so the firs customer has
forgotten her seat number and have chosen a random seat. When the following customers
enter the airplane and find their seat taken they pick a random free seat.
The question is what is the probability that last customer that enters the plane finds
her seat taken as a function of `n`.
Run the simulation to find out if you do not know the answer!

## Next steps

This is the end of this introductory tutorial. More advanced features are covered
in examples contained in `/examples/` directory.
