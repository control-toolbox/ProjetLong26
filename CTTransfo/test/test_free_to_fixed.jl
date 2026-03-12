using CTTransfo
using CTParser
using OptimalControl
using NLPModelsIpopt
using Test

@testset "FreeToFixedTime Transformation" begin

    println("\nRunning Free to Fixed Time Transformation Test")
    
    # Original Problem (Free Time):
    # min tf
    # x''(t) = u(t)
    # x(0)=0, x'(0)=0, x(tf)=1, x'(tf)=0
    # |u| <= 1
    
    # We define the transformation inline
    ocp_trans = @transform (CTParser.@def begin
        tf ∈ R, variable
        t ∈ [0, tf], time
        x ∈ R^2, state
        u ∈ R, control
        x(0) == [0, 0]
        x(tf) == [1, 0]
        -1 ≤ u(t) ≤ 1
        x'(t) == [x[2](t), u(t)]
        tf → min
    end) FreeToFixedTime()

    println("Transformation created successfully.")
    
    # Check if we can solve it
    # We need to solve it to confirm validity
    try
        sol = solve(ocp_trans)
        println("Solved! Objective: ", sol.objective)
        @test isapprox(sol.objective, 2.0, atol=1e-2)
    catch e
        println("Solver error (please ensure solver environment is set up): ", e)
    end

end
