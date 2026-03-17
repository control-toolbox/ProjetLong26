# CTTransfo: Optimal Control Problem Transformations

A Julia package for applying transformations to optimal control problems (OCP) defined using [CTModels.jl](https://github.com/control-toolbox/CTModels.jl) and parsed with [CTParser.jl](https://github.com/control-toolbox/CTParser.jl).

## Overview

CTTransfo allows you to transform optimal control problems while preserving their structure. Currently supports:

- **Identity Transformation**: Pass-through transformation (useful for testing and as a template)
- **Time Substitution**: Rescale the time interval of an OCP to a new interval


## Quick Start

### Define an OCP

```julia
using CTParser, OptimalControl, CTTransfo

ocp = CTParser.@def begin
    t ∈ [8.0, 10.0], time
    x ∈ R², state
    u ∈ R, control
    x(8.0) == [-1, 0]
    x(10.0) == [0, 0]
    ẋ(t) == 2 * [x₂(t), u(t)]
    2 * ∫( 0.5u(t)^2 ) → min
end
```

### Apply an Identity Transformation

```julia
n_ocp = @transform ocp Identity() true

# Solve both
sol = OptimalControl.solve(ocp)
n_sol = OptimalControl.solve(n_ocp)
```

### Apply Time Substitution

Rescale time from `[t0, tf]` to `[0, 1]`:

```julia
# Transform the original OCP: time [8.0, 10.0] → [0.0, 1.0]
transformed_ocp = @transform ocp TimeSubstitution(0.0, 1.0) true

# Solve
sol = OptimalControl.solve(transformed_ocp)
```

## Transformations

### Identity Transformation

**Purpose**: Pass-through transformation. Each constraint or equation is parsed and returned unchanged.

**Usage**:
```julia
transformed = @transform ocp Identity() log_flag
```

**What it does**:
- Registers a custom parsing backend
- Re-parses the OCP definition using this identity backend
- Returns an equivalent OCP (useful for testing the transformation framework)

### Time Substitution

**Purpose**: Rescale the time interval of an OCP from `[t0, tf]` to `[s0, sf]`.

**Usage**:
```julia
# Transform time interval [8.0, 10.0] to [0.0, 1.0]
transformed = @transform ocp TimeSubstitution(0.0, 1.0) log_flag
```

**Requirements**:
- OCP must use **literal float constants** for time bounds, not variables
- Works only when `@transform` is applied in the same scope as the OCP definition

**What it does**:
- Substitutes time variable: `t = t0 + (tf - t0) / (sf - s0) * (s - s0)`
- Scales dynamics: `∂x/∂t = k * ∂x/∂s` where `k = (tf - t0) / (sf - s0)`
- Scales integral terms in objectives: multiplies Lagrange and Mayer terms by `k`
- Preserves boundary conditions and constraints with adapted time references

**Example**:
```julia
ocp = CTParser.@def begin
    t ∈ [8.0, 10.0], time  # Use literal floats
    x ∈ R², state
    u ∈ R, control
    # ... problem definition
end

rescaled_ocp = @transform ocp TimeSubstitution(0.0, 1.0) false
# Now rescaled_ocp has time ∈ [0.0, 1.0]
```

**Limitations**: Time bounds must be evaluable float numbers; symbolic bounds like `t ∈ [t0, tf]` will not work reliably.

## Architecture & Design Choices

### Custom Parsing Backend System

The transformation framework uses CTParser's **custom backend system** to intercept and modify parsing:

```
OCPDefinition 
    ↓ (extract as Expr)
CTParser.parse!() with custom backend
    ↓
Transformed parse tree
    ↓ (wrap with PreModel setup)
CTParser.def_fun() wrapper
    ↓
CTModels.Model (actual OCP)
```

**Design Choice**: Each transformation registers a `TransfoBackend` containing a dictionary of transformation functions:
- `:time`, `:state`, `:control` (variable definitions)
- `:constraint`, `:dynamics`, `:lagrange`, `:mayer` (equations/objectives)

This allows fine-grained control over how each parsing rule is transformed.

### Code Generation Flow

The transformation process uses code generation:

1. Extract OCP definition as an `Expr` from the `CTModels.Model`
2. Parse it through CTParser with a custom backend
3. Collect transformed parsing results
4. Wrap with `PreModel()`, `definition!()`, `time_dependence!()`, and `build()` calls
5. Evaluate to get the final OCP

This ensures the transformed OCP is **structurally identical** to one created directly with `@def`.

## Architectural Limitations

The current implementation uses **backend injection** through CTParser's custom backend system. While this works in some cases, it creates several fundamental limitations that would be solved by directly modifying the OCP model instead.

**Key Insight**: After attempting to fix these issues, it became clear that the backend injection approach is fundamentally constrained:
- Cannot access runtime context (variables, module scope) at macro compile-time
- Cannot use `__wrap` for error messages due to syntax incompatibility
- String-based transformations are fragile and error-prone
- Requires re-parsing the entire OCP definition just to apply local changes

**Better Approach**: Directly traverse and modify the `CTModels.Model` object after creation, transforming the internal constraint/dynamics/objective representations without re-parsing. This would:
- Work with symbolic bounds (they're just evaluated at that point)
- Preserve original error contexts and line numbers
- Be more efficient (no re-parsing needed)
- Allow safer AST-based transformations
- Give full control over the model structure

**Migration Path**: New transformations should either:
1. Work directly on `CTModels.Model` objects post-definition, or
2. Extend CTParser's backend system only for simple pass-through transformations

## Known Issues & Limitations

### 1. **@transform Requires OCP in Same Scope**

The `@transform` macro evaluates the OCP at compile time using the macro's module context. It cannot access variables from outside scopes:

```julia
# FAILS - t0, tf not accessible to macro
t0 = 0.0; tf = 10.0
ocp = CTParser.@def begin
    t ∈ [t0, tf], time
    # ...
end
transformed = @transform ocp TimeSubstitution(0.0, 1.0)
```

**Root Cause**: Macros execute at compile time before runtime variable bindings exist.

**Workaround**: Use literal float constants:
```julia
# ✓ WORKS
ocp = CTParser.@def begin
    t ∈ [0.0, 10.0], time
    # ...
end
transformed = @transform ocp TimeSubstitution(0.0, 1.0)
```

### 2. **String-Based replace_calls Can Replace Wrong Variables**

The `replace_calls()` function in TimeSubstitution uses string replacement to adapt time references. This can accidentally match unrelated expressions:

```julia
# DANGEROUS
ocp = CTParser.@def begin
    t ∈ [0.0, 10.0], time
    x ∈ R², state
    u ∈ R, control
    x(0.0) == 2 * (0.0)  # This (0.0) gets replaced!
    # ...
end
```

If the original time bounds are `0.0`, string replacement can match `(0.0)` in unrelated expressions like `2 * (0.0)`.

**Root Cause**: Uses naive string `replace(line, "(original_t0)" => "new_t0")` which matches any occurrence.

**Workaround**: Ensure time bounds don't appear as literals elsewhere in the problem.

### 3. **TimeSubstitution Only Works with Float Times**

The time substitution assumes `original_t0` and `original_tf` are float constants that can be subtracted and divided:

```julia
# FAILS
ocp = CTParser.@def begin
    t ∈ [0, 10], time  # Integers, not floats
    # ...
end
```

**Root Cause**: The scaling factor `k = (tf - t0) / (sf - s0)` is computed symbolically but expects numeric types.

**Workaround**: Use float literals:
```julia
# WORKS
ocp = CTParser.@def begin
    t ∈ [0.0, 10.0], time
    # ...
end
```

### 4. **Error Messages Are Not User-Friendly**

The transformation framework cannot use CTParser's `__wrap()` function (which provides nice error messages with line numbers and context) because `__wrap` adds try-catch blocks with `local ex` statements that break the `def` syntax.

Instead, transformations use bare `Meta.parse()`, which provides minimal error feedback:

```julia
# Instead of this (from CTParser):
# return CTParser.__wrap(code, p.lnum, p.line)

# We must use this (in transformations):
return Meta.parse(p.line)
```

**Root Cause**: The `__wrap` try-catch structure is incompatible with the `def` block syntax that accumulates constraints and equations.

**Impact**: User errors in OCPs produce bare parsing errors without source location info, making debugging difficult.

### 5. **Limited Transformation Examples**

Only two transformations implemented. More needed for:
- Variable substitutions
- Free time to fixed time
- Changing the cost type

## Testing

```bash
cd CTTransfo
julia test/runtests.jl
```

The test suite includes:
- Identity transformation on a simple 2D OCP
- Time substitution on a rocket trajectory problem
- Solution verification that transformed OCP produces equivalent results

## File Structure

```
CTTransfo/
├── src/
│   ├── CTTransfo.jl           # Main module
│   ├── transformation.jl       # Core transformation framework
│   ├── identity.jl             # Identity transformation
│   ├── time_substitution.jl    # Time rescaling transformation
├── test/
│   └── runtests.jl            # Test suite
├── Project.toml
├── Manifest.toml
└── README.md
```
