using OptimalControl
using NLPModelsIpopt
using Plots

ocp = @def begin

    tf ∈ R,          variable
    t ∈ [0, tf],     time
    x = (q, v) ∈ R², state
    u ∈ R,           control

    -1 ≤ u(t) ≤ 1

    q(0)  == -1
    v(0)  == 0
    q(tf) == 0
    v(tf) == 0

    ẋ(t) == [v(t), u(t)]

    tf → min

end

sol = solve(ocp; grid_size=200)
plt = Plots.plot(sol; label="Direct", size=(800, 600))