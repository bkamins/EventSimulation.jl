# EventSimulation Tutorial

## Installation

In REPL run `Pkg.add("EventSimulation")` to install the package and next
`using EventSimulation` to start using it.

## First simulation

This is a bare minimum simulation using EventSimulation:

```
using EventSimulation

function arrived(s)
    t = s.now
    println("Arrived at ", s.now)
    register!(s, x -> println("Left at $(x.now) that arrived at $t"), 1.5)
end

s = Scheduler()
for t in 1.0:5.0
    register!(s, arrived, t)
end

go!(s)
```

In this example five customers arrive at times 1, 2, ..., 5 and stay in the
system for 1.5 time units. Observe that in `arrived` we use a closure to define
anonymous function that is registered. In its body `x.now` will be taken from
the state of the scheduler when the anonymous function is invoked but `t` is
fixed in enclosing scope of `arrived` function as the time of the arrival.

!!! Exercise

    Test what happens if you replace `$t` with `$(s.now)` in the anonymous
    function. What is the reason of this behavior?

When using EventSimulation working with closures is often the simplest way
to develop a simulation so it is important that you understand this example.
