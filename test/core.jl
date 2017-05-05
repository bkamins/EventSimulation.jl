es = EmptyState()

println("Testing core Scheduler creation")
sReal = Scheduler{EmptyState, Real}(1.2, Vector{EventSimulation.Action{Real}}(), es)

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
@test rrv == [1,3,7,15,31,63]

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

