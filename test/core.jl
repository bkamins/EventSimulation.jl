es = EmptyState()

println("Testing core Scheduler creation")
sReal = Scheduler{EmptyState, Real}(1.2, Vector{EventSimulation.Action{Real}}(), es, (a,b)->nothing)

println("Testing if register! and go! produce correct order")
s = Scheduler()

mlen = 100
ts = (1.0:mlen)[randperm(mlen)]

for x in ts
    register!(s, z -> push!(v, z.now), x)
end

v = Float64[]
go!(s, mlen)
@test v == [1.0:mlen;]
@test length(s.event_queue) == 0


println("Testing register! and terminate! for correct number of elements")
for x in ts
    register!(s, z -> push!(v, z.now), x)
end

@test length(s.event_queue) == mlen
terminate!(s)
@test length(s.event_queue) == 0


println("Testing repeat_register!")
s = Scheduler()
rrv = []
f(x) = push!(rrv, x.now)
ifun(x) = x.now + 1
repeat_register!(s, f, ifun)
go!(s, 50)
@test rrv == [1,3,7,15,31]

s = Scheduler()
rrv = []
f(x) = push!(rrv, x.now)
ifun2(x) = length(rrv) < 5 ? x.now + 1 : NaN
repeat_register!(s, f, ifun2)
go!(s)
@test length(rrv) == 5


println("Testing ordered bulk_register!")
s = Scheduler()
v2 = []
who = [1:5;]
for x in randperm(10)
    bulk_register!(s, who, (a,b) -> push!(v2, (s.now, b)), Float64(x), false)
end
go!(s, 11)
v2t = []
for i in 1.0:10.0, j in 1:5
    push!(v2t, (i, j))
end

@test v2 == v2t

println("Testing random bulk_register!. Visual inspection required.")
println("First element of tuple should be ordered, second should be in random order")
s = Scheduler()
v2 = []
who = [1:5;]
for x in randperm(4)
    bulk_register!(s, who, (a,b) -> println((s.now, b)), Float64(x), true)
end
go!(s, 11)

println("Testing ordered repeat_bulk_register!")
s = Scheduler()
v2 = []
who = [1:5;]
repeat_bulk_register!(s, who, (a,b) -> push!(v2, (s.now, b)), x -> 1.0, false)
go!(s, 10)
v2t = []
for i in 1.0:10.0, j in 1:5
    push!(v2t, (i, j))
end

@test v2 == v2t

s = Scheduler()
v2 = []
who = [1:5;]
repeat_bulk_register!(s, who, (a,b) -> push!(v2, (s.now, b)),
    x -> length(v2) < length(v2t) ? 1.0 : Inf, false)
go!(s)

@test v2 == v2t

println("Testing random repeat_bulk_register!. Visual inspection required.")
println("First element of tuple should be ordered, second should be in random order")
s = Scheduler()
v2 = []
who = [1:5;]
repeat_bulk_register!(s, who, (a,b) -> println((s.now, b)), x -> 1.0, true)
go!(s, 4)


println("Testing interrupt.")

s = Scheduler()
@test interrupt!(s, EventSimulation.Action(identity, 1.0)) == false
for i in 1:10
    register!(s, identity, rand())
end

OK = true
a = register!(s, x -> begin global OK = false; println("Failed") end, rand())

for i in 1:10
    register!(s, identity, rand())
end

@test interrupt!(s, a) == true
go!(s, 1.0)
@test OK

println("Testing monitor.")
s = Scheduler()
deltas = Float64[]
s.monitor = (s,Δ) -> push!(deltas, Δ)
repeat_register!(s, x -> nothing, x -> rand())
go!(s, 100_000)
m = mean(deltas)
v = var(deltas)
println("mean: $m, var: $v")
@test max(abs(m-0.5), abs(v-1/12)) < 0.005
