using CTTransfo
using CTParser
using CTModels
using OptimalControl
using NLPModelsIpopt
using Plots
using Parameters
using Test


@testset "CTTransfo Tests" begin

    ocp = CTParser.@def begin
        t ∈ [8.0, 10.0], time
        x ∈ R², state
        u ∈ R, control
        x(8.0) == [-1, 0]
        x(10.0) == 2 * [0, 0]
        ẋ(t) == 2 * [x₂(t), u(t)]
        2 * ∫( 0.5u(t)^2 ) → min
    end


    g0 = 1.0; m0 = 1.0; h0 = 1.0; hc = 500.0; mc = 0.6
    c  = 0.5 * sqrt(g0 * h0)
    Dc = 0.5 * 620 * m0 / g0
    Tm = 3.5 * g0 * m0
    t0 = 0.0; tf = 0.2

    drag(h, v) = Dc * v^2 * exp(-hc * (h - h0) / h0)
    grav(h)    = g0 * (h0 / h)^2

    ocp2 = CTParser.@def begin
        t ∈ [t0, tf], time
        x = (h, v, m) ∈ R^3, state
        T ∈ R, control

        0 ≤ T(t) ≤ Tm
        mc ≤ m(t) ≤ m0

        ∂(h)(t) == v(t)
        ∂(v)(t) == (T(t) - drag(h(t), v(t))) / m(t) - grav(h(t))
        ∂(m)(t) == -T(t) / c

        h(t0) == 1.0
        v(t0) == 0.0
        m(t0) == 1.0
        m(tf) == 0.6
        h(tf) → max
    end


    sol1 = OptimalControl.solve(ocp)
    p1 = Plots.plot(sol1)
    Plots.savefig(p1, "original_solution.png")

    n_ocp = @transform ocp Identity() true

    sol = OptimalControl.solve(n_ocp)
    p = Plots.plot(sol)
    Plots.savefig(p, "identity_solution_plot.png")

    n_ocp2 = @transform n_ocp TimeSubstitution(0.0, 1.0) true

    sol2 = OptimalControl.solve(n_ocp2)
    p2 = Plots.plot(sol2)
    Plots.savefig(p2, "timesub_solution_plot.png")
end
