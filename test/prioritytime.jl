@testset "Testing Scheduler with PriorityTime" begin
    s = Scheduler(EmptyState(), PriorityTime{Int, Int})
    ptv = []
    for i in 1:100
        a = rand(1:5)
        b = rand(1:5)
        register!(s, x -> push!(ptv, s.now), PriorityTime(a,b))
    end
    go!(s, 10)

    for i in 1:length(ptv)-1
        a = ptv[i]
        b = ptv[i+1]
        @test a<=b
        @test (a.time < b.time) || (a.time == b.time && a.priority <= b.priority)
    end
end

@testset "Testing +, -, promotion and conversion" begin
    pt1 = PriorityTime(1)
    pt2 = PriorityTime(2.0, 1)
    pt3 = pt1 + pt2
    pt4 = pt1 - pt2
    @test pt3.time == pt1.time + pt2.time
    @test pt3.priority == pt1.priority + pt2.priority
    @test pt4.time == pt1.time - pt2.time
    @test pt4.priority == pt1.priority - pt2.priority

    pt5 = pt1 + 1.0
    @test pt5.time == pt1.time + 1.0
    @test pt5.priority == pt1.priority
    pt6 = 1.0 + pt1
    @test pt6.time == pt1.time + 1.0
    @test pt6.priority == pt1.priority

    pt_if = PriorityTime(1, 1.0)
    pt_bb = PriorityTime(big(1.0), big(1))
    @test pt_if+pt_bb == PriorityTime(big(2.0), big(2.0))
end

@testset "Testing zero" begin
    z1 = zero(PriorityTime{Int, Int16})
    z2 = zero(z1)
    @test z1 == z2
    @test typeof(z1) == typeof(z2)
    @test isa(z1, PriorityTime{Int, Int16})
end

@testset "Testing comparison" begin
    ptc1 = PriorityTime(1,1)
    ptc2 = PriorityTime(1.0,1.0)
    @test isequal(ptc1, ptc2)
    @test hash(ptc1) == hash(ptc2)
    @test ptc1 == ptc2
    @test !(ptc1 != ptc2)
    @test ptc1 <= ptc2
    @test !(ptc1 < ptc2)
    @test ptc1 >= ptc2
    @test !(ptc1 > ptc2)

    ptc3 = PriorityTime(1.0,1.1)
    @test !isequal(ptc1, ptc3)
    @test hash(ptc1) != hash(ptc3)
    @test !(ptc1 == ptc3)
    @test ptc1 != ptc3
    @test ptc1 <= ptc3
    @test ptc1 < ptc3
    @test !(ptc1 >= ptc3)
    @test !(ptc1 > ptc3)

    ptc4 = PriorityTime(1.1,0.1)
    @test !isequal(ptc1, ptc4)
    @test hash(ptc1) != hash(ptc4)
    @test !(ptc1 == ptc4)
    @test ptc1 != ptc4
    @test ptc1 <= ptc4
    @test ptc1 < ptc4
    @test !(ptc1 >= ptc4)
    @test !(ptc1 > ptc4)

    tc4 = Int16(2)
    @test !isequal(ptc1, tc4)
    @test hash(ptc1) != hash(tc4)
    @test !(ptc1 == tc4)
    @test ptc1 != tc4
    @test ptc1 <= tc4
    @test ptc1 < tc4
    @test !(ptc1 >= tc4)
    @test !(ptc1 > tc4)
end

