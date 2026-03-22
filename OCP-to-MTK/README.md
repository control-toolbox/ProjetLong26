# OCP to MTK

Transforming optimal control problems from OptimalControl.jl (OCP) to ModelingToolkit.jl (MTK)

## Transformation
The transformation from a problem in OCP to a problem in MTK can be done with the file `convert_ocp_to_mtk.jl`.
The folder `convert_tests/` contains tests for the conversion done with this file.

## Examples
In the folder `examples/`, there are examples of problems in OCP and their equivalents in MTK:

- A problem with free final time
- A problem with integral cost
- A problem with a path constraint

## Difficulties in transforming from OCP to MTK

- Integral cost 
    - Introducing a variable to write the problem with a Mayer formulation
- Constraints
    - Bounds
        - For example $u\in[-10,10]$:  
        `u(..), [input = true, bounds = (-10, 10)]`
    - Other constraints
        - For example the path constraint $x2(t)+u(t)\leq4$:  
        `Symbolics.Inequality(x2(t) + u(t), 4, ≤)`
- Dynamic optimization solvers
    - [Here](https://docs.sciml.ai/ModelingToolkit/dev/API/dynamic_opt/#dynamic_opt_api) are the 4 solvers available for optimal control problems in MTK, but many parts of the documentation are still missing
- Differences between `@variables` and `@parameters`
    - `@parameters` (and other macro: `@independent_variables`, `@constants` and `@brownians`) works like `@variables` but allows MTK to attach additional metadata to it