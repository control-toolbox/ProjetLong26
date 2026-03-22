using ModelingToolkit, InfiniteOpt, Ipopt, DiffEqDevTools, CairoMakie

t = ModelingToolkit.t_nounits
D = ModelingToolkit.D_nounits

ModelingToolkit.@variables begin
    q(..)
    v(..)
    u(..), [input = true, bounds = (-1, 1)]
end

@parameters tf

# Dynamics
eqs = [
    D(q(t)) ~ v(t),
    D(v(t)) ~ u(t),
]

ts = 0.0
tspan = (ts, tf)

# Terminal cost
costs = [tf]

# Boundary conditions
cons = [
    q(ts) ~ -1.0,
    v(ts) ~  0.0,
    q(tf) ~ 0.0,
    v(tf) ~ 0.0,
]

# Compile the system
@named ocp = System(eqs, t; costs, constraints = cons)
ocp = mtkcompile(ocp, inputs = [u(t)])

# Initial guess
u0map = [
    q(t) => -1.0,
    v(t) => 0.0,
    u(t)  => 0.0
]

parammap = [tf => 1.0]

# Build and solve
iprob = InfiniteOptDynamicOptProblem(ocp, [u0map; parammap], tspan; steps = 100)
isol = solve(iprob, InfiniteOptCollocation(Ipopt.Optimizer));

# Plot
fig = Figure(resolution = (800, 400))
ax1 = Axis(fig[1, 1], title = "Variables", xlabel = "Time")
ax2 = Axis(fig[1, 2], title = "Control", xlabel = "Time")

for unknown in unknowns(ocp)
    lines!(ax1, isol.sol.t, isol.sol[unknown], label = string(unknown))
end
lines!(ax2, isol.input_sol, label = "u(t)")
axislegend(ax1)
axislegend(ax2)
fig
