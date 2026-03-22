using ModelingToolkit, InfiniteOpt, Ipopt, DiffEqDevTools, CairoMakie, DynamicQuantities

t = ModelingToolkit.t_nounits
D = ModelingToolkit.D_nounits

ModelingToolkit.@variables begin
    x1(..)
    x2(..)
    u(..), [input = true]
    J(..)      # auxiliary state for cost integral
end

# Dynamics
eqs = [
    D(x1(t)) ~ x2(t),
    D(x2(t)) ~ u(t),
    D(J(t))  ~ 0.5 * u(t)^2  # running cost integrated
]

(ts, te) = (0.0, 1.0)

# Terminal cost
costs = [J(te)]

# Boundary conditions
cons = [
    x1(ts) ~ -1.0,
    x2(ts) ~ 0.0,
    x1(te) ~ 0.0,
    x2(te) ~ 0.0,
    J(ts) ~ 0.0
]

# Compile the system
@named ocp = System(eqs, t; costs, constraints = cons)
ocp = mtkcompile(ocp, inputs = [u(t)])

# Initial guess
u0map = [
    x1(t) => -1.0,
    x2(t) => 0.0,
    u(t)  => 0.0,
    J(t)  => 0.0
]

# Build and solve
jprob = JuMPDynamicOptProblem(ocp, u0map, (ts, te); dt = 0.01)
jsol = solve(jprob, JuMPCollocation(Ipopt.Optimizer, constructRadauIIA5()));

# Plot
fig = Figure(resolution = (800, 400))
ax1 = Axis(fig[1, 1], title = "Variables", xlabel = "Time")
ax2 = Axis(fig[1, 2], title = "Control", xlabel = "Time")

for unknown in unknowns(ocp)
    lines!(ax1, jsol.sol.t, jsol.sol[unknown], label = string(unknown))
end
lines!(ax2, jsol.input_sol, label = "u(t)")
axislegend(ax1)
axislegend(ax2)
fig
