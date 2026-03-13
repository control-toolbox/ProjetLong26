using CTTransfo
using CTParser
using CTModels
using OptimalControl
using NLPModelsIpopt
using Plots
using Parameters
using Test

# --------------------------------------------------------------------------------------------------
# Example: Time Scaling Transformation with Internal Parameters
# --------------------------------------------------------------------------------------------------

function p_time_scaling_transfo!(t_struct, p, p_ocp, t, t0, tf)
    t0 = clean_name(t0)
    tf = clean_name(tf)
    k = t_struct.k
    println("  -> Applying Time Scaling (factor k=$k)")
    
    new_t0 = t0 * k
    new_tf = tf * k
    return :($t ∈ [$new_t0, $new_tf], time)
end

@with_kw mutable struct TimeScaling <: AbstractTransformation
    k::Float64
    backend::TransfoBackend = TransfoBackend(name=:time_scaling)
end

function TimeScaling(k::Float64)
    ts = TimeScaling(k=k)
    ts.backend.transfo_dict[:time] = (args...) -> p_time_scaling_transfo!(ts, args...)
    CTTransfo.add_backend!(ts.backend)
    return ts
end

@testset "CTTransfo Tests" begin

    # ocp = @transform (CTParser.@def begin
    #     t ∈ [0, 1], time
    #     x ∈ R², state
    #     u ∈ R, control
    #     x(0) == [-1, 0]
    #     x(1) == 2 * [0, 0]
    #     ẋ(t) == 2 * [x₂(t), u(t)]
    #     2 * ∫( 0.5u(t)^2 ) → min
    # end) TimeSubstitution(8, 10)

    g0 = 1.0; m0 = 1.0; h0 = 1.0; hc = 500.0; mc = 0.6
    c  = 0.5 * sqrt(g0 * h0)
    Dc = 0.5 * 620 * m0 / g0
    Tm = 3.5 * g0 * m0

    drag(h, v) = Dc * v^2 * exp(-hc * (h - h0) / h0)
    grav(h)    = g0 * (h0 / h)^2

    ocp = CTParser.@def begin
        t ∈ [0.0, 0.2], time
        x = (h, v, m) ∈ R^3, state
        T ∈ R, control

        0 ≤ T(t) ≤ Tm
        mc ≤ m(t) ≤ m0

        ∂(h)(t) == v(t)
        ∂(v)(t) == (T(t) - drag(h(t), v(t))) / m(t) - grav(h(t))
        ∂(m)(t) == -T(t) / c

        h(0.0) == 1.0
        v(0.0) == 0.0
        m(0.0) == 1.0
        m(0.2) == 0.6
        h(0.2) → max
    end

    # sol1 = OptimalControl.solve(ocp)
    # p1 = Plots.plot(sol1)
    # Plots.savefig(p1, "original_solution.png")

    n_ocp = @transform ocp TimeSubstitution(0.0, 1.0) false
    # n_ocp = @transform ocp FreeToFixedTime()

    sol = OptimalControl.solve(n_ocp)
    p = Plots.plot(sol)
    Plots.savefig(p, "transformation_solution_plot.png")
end
