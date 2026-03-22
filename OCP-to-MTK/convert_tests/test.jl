using InfiniteOpt
using Ipopt
using OrdinaryDiffEq
using DiffEqDevTools
using CairoMakie

include("../convert_ocp_to_mtk.jl")

g0 = 1.0; m0 = 1.0; h0 = 1.0; hc = 500.0; mc = 0.6
c  = 0.5 * sqrt(g0 * h0)
Dc = 0.5 * 620 * m0 / g0
Tm = 3.5 * g0 * m0
t0 = 0.0; tf = 0.2

drag(h, v) = Dc * v^2 * exp(-hc * (h - h0) / h0)
grav(h)    = g0 * (h0 / h)^2

ocp_test = @def begin
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

rocket, u0map = convert_ocp_to_mtk(
    ocp_test, t0, tf; 
    sys_name = :rocket,
    init_state = [1.0, 0.0, 1.0], 
    init_control = [0.0]
)

jprob = JuMPDynamicOptProblem(rocket, u0map, (t0, tf); dt = 0.001)
jsol  = solve(jprob, JuMPCollocation(Ipopt.Optimizer, constructRadauIIA5()))

println("Affichage des résultats...")

fig = Figure(size = (900, 450))
ax1 = Axis(fig[1, 1], title = "Trajectoire (h, v, m)", xlabel = "Temps (s)")
ax2 = Axis(fig[1, 2], title = "Poussée", xlabel = "Temps (s)")

for u in unknowns(rocket)
    lines!(ax1, jsol.sol.t, jsol.sol[u], label = string(u), linewidth=2)
end

stairs!(ax2, jsol.sol.t, jsol.input_sol[1, :], label = "Poussée T(t)", color=:red, linewidth=2, step=:post)

axislegend(ax1, position=:lt)
axislegend(ax2)
display(fig)

