using InfiniteOpt
using Ipopt
using OrdinaryDiffEq
using DiffEqDevTools
using CairoMakie
using OptimalControl

include("convert_ocp_to_mtk.jl")

t0 = 0.0
tf = 2.0

ocp_chariot = @def begin
    t ∈ [t0, tf], time  
    x = (q, v, E) ∈ R^3, state  
    u ∈ R, control              

    -2.0 ≤ u(t) ≤ 2.0
    
    ∂(q)(t) == v(t)
    ∂(v)(t) == u(t)
    ∂(E)(t) == u(t)^2  

    E(tf) → min
end

t_sym, x_sym, u_sym, _, _ = translate_universal_ocp_to_mtk(ocp_chariot)
q, v_etat, E_etat = make_callables(x_sym)

mes_contraintes = [
    q(t0) ~ 0.0,
    v_etat(t0) ~ 0.0,
    E_etat(t0) ~ 0.0,
    q(tf) ~ 1.0,        
    v_etat(tf) ~ 0.0
]

sys_chariot, u0map = convert_ocp_to_mtk(
    ocp_chariot, t0, tf; 
    sys_name = :chariot,
    extra_cons = mes_contraintes, 
    init_state = [0.0, 0.0, 0.0], 
    init_control = [0.0]
)

jprob = JuMPDynamicOptProblem(sys_chariot, u0map, (t0, tf); dt = 0.01)
jsol  = solve(jprob, JuMPCollocation(Ipopt.Optimizer, constructRadauIIA5()))

fig = Figure(size = (800, 400))
ax1 = Axis(fig[1, 1], title = "États du Chariot", xlabel = "Temps (s)")
ax2 = Axis(fig[1, 2], title = "Commande (Accélération)", xlabel = "Temps (s)")

for u in unknowns(sys_chariot)
    lines!(ax1, jsol.sol.t, jsol.sol[u], label = string(u), linewidth=2)
end
stairs!(ax2, jsol.sol.t, jsol.input_sol[1, :], label = "u(t)", color=:blue, linewidth=2, step=:post)

axislegend(ax1, position=:lt)
axislegend(ax2)
display(fig)