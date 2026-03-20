using OptimalControl

using ModelingToolkit

using Symbolics



# 1. Récupération des paramètres du problème

function translate_universal_ocp_to_mtk(ocp)

    state_names = OptimalControl.state(ocp).components

    control_names = OptimalControl.control(ocp).components

    nx, nu = length(state_names), length(control_names)

   

    ModelingToolkit.@independent_variables t

    D = Differential(t)



    x_vec = Num[only(ModelingToolkit.@variables $(Symbol(state_names[i]))(t)) for i in 1:nx]

    u_vec = Num[only(ModelingToolkit.@variables $(Symbol(control_names[i]))(t) [input=true]) for i in 1:nu]

    v_vec = Num[]



    f_dyn = OptimalControl.dynamics(ocp)

    dx_vec = Vector{Num}(undef, nx)

    f_dyn(dx_vec, t, x_vec, u_vec, v_vec)

   

    eqs = [D(x_vec[i]) ~ dx_vec[i] for i in 1:nx]



    constraints_eqs = []

    cm = OptimalControl.constraints(ocp)

   

    if length(cm.state_box) == 4

        lbs, indices, ubs, labels = cm.state_box

        for i in 1:length(lbs)

            idx = indices[i]

            if lbs[i] > -Inf push!(constraints_eqs, ModelingToolkit.:≲(lbs[i], x_vec[idx])) end

            if ubs[i] < Inf  push!(constraints_eqs, ModelingToolkit.:≲(x_vec[idx], ubs[i])) end

        end

    end

    if length(cm.control_box) == 4

        lbs, indices, ubs, labels = cm.control_box

        for i in 1:length(lbs)

            idx = indices[i]

            if lbs[i] > -Inf push!(constraints_eqs, ModelingToolkit.:≲(lbs[i], u_vec[idx])) end

            if ubs[i] < Inf  push!(constraints_eqs, ModelingToolkit.:≲(u_vec[idx], ubs[i])) end

        end

    end



    return t, x_vec, u_vec, eqs, constraints_eqs

end



# 2. L'utilitaire d'appel

function make_callables(sym_array)

    return [(args...) -> Num(Symbolics.operation(Symbolics.unwrap(sym))(args...)) for sym in sym_array]

end



# 3. L'extracteur automatique de bornes

function auto_extract_boundaries(ocp, x_sym, u_sym, v_sym, ts, te)

    x_call = make_callables(x_sym)

    x0 = [x(ts) for x in x_call]

    xf = [x(te) for x in x_call]



    boundary_cons = []

    cm = OptimalControl.constraints(ocp)

   

    # 1. Contraintes initiales

    if hasproperty(cm, :initial) && length(cm.initial) == 4

        lbs, f_init, ubs, labels = cm.initial

        res = Vector{Num}(undef, length(lbs))

        f_init(res, x0, v_sym)

        for i in 1:length(lbs)

            if lbs[i] == ubs[i] push!(boundary_cons, res[i] ~ lbs[i])

            else

                if lbs[i] > -Inf push!(boundary_cons, ModelingToolkit.:≲(lbs[i], res[i])) end

                if ubs[i] < Inf  push!(boundary_cons, ModelingToolkit.:≲(res[i], ubs[i])) end

            end

        end

    end



    # 2. Contraintes finales

    if hasproperty(cm, :final) && length(cm.final) == 4

        lbs, f_final, ubs, labels = cm.final

        res = Vector{Num}(undef, length(lbs))

        f_final(res, xf, v_sym)

        for i in 1:length(lbs)

            if lbs[i] == ubs[i] push!(boundary_cons, res[i] ~ lbs[i])

            else

                if lbs[i] > -Inf push!(boundary_cons, ModelingToolkit.:≲(lbs[i], res[i])) end

                if ubs[i] < Inf  push!(boundary_cons, ModelingToolkit.:≲(res[i], ubs[i])) end

            end

        end

    end



    # 3. Contraintes frontières globales

    if hasproperty(cm, :boundary) && length(cm.boundary) == 4

        lbs, f_bound, ubs, labels = cm.boundary

        res = Vector{Num}(undef, length(lbs))

        f_bound(res, x0, xf, v_sym)

        for i in 1:length(lbs)

            if lbs[i] == ubs[i] push!(boundary_cons, res[i] ~ lbs[i])

            else

                if lbs[i] > -Inf push!(boundary_cons, ModelingToolkit.:≲(lbs[i], res[i])) end

                if ubs[i] < Inf  push!(boundary_cons, ModelingToolkit.:≲(res[i], ubs[i])) end

            end
        end
    end



    costs = Num[]

    obj = ocp.objective

    if hasproperty(obj, :mayer) && obj.mayer !== nothing
        cost_expr = obj.mayer(x0, xf, v_sym)
        push!(costs, obj.criterion == :max ? -cost_expr : cost_expr)

    end



    return costs, boundary_cons

end



# 4. L'assembleur de système

function assemble_mtk_system(t_sym, u_sym, sys_eqs, sys_cons, costs, boundary_cons; sys_name=:opt_system)

    toutes_les_contraintes = vcat(sys_cons, boundary_cons)

    @named sys = System(sys_eqs, t_sym; costs=costs, constraints=toutes_les_contraintes)

    return mtkcompile(sys, inputs = u_sym)

end



# 5. Le convertisseur

function convert_ocp_to_mtk(ocp, ts, te; sys_name=:opt_system, extra_cons=[], init_state=[], init_control=[])

    println("Conversion ODP -> MTK...")

    t_sym, x_sym, u_sym, sys_eqs, sys_cons = translate_universal_ocp_to_mtk(ocp)

    v_sym = Num[]

    costs, boundary_cons = auto_extract_boundaries(ocp, x_sym, u_sym, v_sym, ts, te)

    append!(boundary_cons, extra_cons)

    # print(boundary_cons)
    compiled_sys = assemble_mtk_system(t_sym, u_sym, sys_eqs, sys_cons, costs, boundary_cons, sys_name=sys_name)
   

    u0map = []
    for i in 1:length(x_sym) push!(u0map, x_sym[i] => (length(init_state) >= i ? Float64(init_state[i]) : 0.0)) end
    for i in 1:length(u_sym) push!(u0map, u_sym[i] => (length(init_control) >= i ? Float64(init_control[i]) : 0.0)) end

   

    println("Conversion terminée")
    return compiled_sys, u0map

end
