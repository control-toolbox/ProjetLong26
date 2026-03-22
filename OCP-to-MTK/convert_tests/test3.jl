using InfiniteOpt
using Ipopt
using OrdinaryDiffEq
using DiffEqDevTools
using CairoMakie
using OptimalControl
include("../convert_ocp_to_mtk.jl")

t0 = 0.0
tf = 10.0

ocp_peche = @def begin
    t ∈ [t0, tf], time  
    x = (X, Y, C) ∈ R^3, state  # Proies, Prédateurs, Pêche cumulée (Catch)
    u ∈ R, control              # Effort de pêche

    # Effort de pêche limité entre 0 (rien) et 1 (effort max)
    0.0 ≤ u(t) ≤ 1.0
    
    # Bornes de sécurité sur l'écosystème pour aider le solveur
    0.0 ≤ X(t) ≤ 5.0
    0.0 ≤ Y(t) ≤ 5.0

    # Dynamique de Lotka-Volterra modifiée avec pêche
    ∂(X)(t) == X(t) - X(t)*Y(t) - u(t)*X(t)
    ∂(Y)(t) == -Y(t) + X(t)*Y(t)
    ∂(C)(t) == u(t)*X(t)  # Accumulation du poisson pêché

    # État initial de l'écosystème
    X(t0) == 0.5
    Y(t0) == 0.7
    C(t0) == 0.0

    # Objectif : Maximiser la pêche totale à la fin des 10 ans
    C(tf) → max
end

sys_peche, u0map = convert_ocp_to_mtk(
    ocp_peche, t0, tf; 
    sys_name = :peche,
    init_state = [0.5, 0.7, 0.0], 
    init_control = [0.0]
)

jprob = JuMPDynamicOptProblem(sys_peche, u0map, (t0, tf); dt = 0.05)
jsol  = solve(jprob, JuMPCollocation(Ipopt.Optimizer, constructRadauIIA5()))

fig = Figure(size = (900, 450))
ax1 = Axis(fig[1, 1], title = "Populations et Pêche", xlabel = "Temps (Années)")
ax2 = Axis(fig[1, 2], title = "Effort de pêche", xlabel = "Temps (Années)")

for u in unknowns(sys_peche)
    lines!(ax1, jsol.sol.t, jsol.sol[u], label = string(u), linewidth=2)
end
stairs!(ax2, jsol.sol.t, jsol.input_sol[1, :], label = "u(t)", color=:darkgreen, linewidth=2, step=:post)

axislegend(ax1, position=:lt)
axislegend(ax2)
display(fig)