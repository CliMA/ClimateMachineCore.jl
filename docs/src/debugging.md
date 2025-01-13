# Debugging

One of the most challenging tasks that users have is: debug a large simulation
that is breaking, e.g., yielding `NaN`s somewhere. This is especially complex
for large models with many terms and implicit time-stepping with all the bells
and whistles that the CliMA ecosystem offers.

ClimaCore has a module, [`ClimaCore.DebugOnly`](@ref), which contains tools for
debugging simulations for these complicated situations.

Because so much data (for example, the solution state, and many cached fields)
is typically contained in ClimaCore data structures, we offer a hook to inspect
this data after any operation that ClimaCore performs.

## Example

### Print `NaNs` when they are found

In this example, we add a callback that simply prints `NaNs found` every
instance when they are detected in a `ClimaCore` operation.

To do this, we need two ingredients:

First, we need to enable the callback system:
```@example
import ClimaCore
ClimaCore.DebugOnly.call_post_op_callback() = true
```

The line `ClimaCore.DebugOnly.call_post_op_callback() = true` means that at the
end of every `ClimaCore` operation, the function
`ClimaCore.DebugOnly.post_op_callback` is called. By default, this function does
nothing. So, the second ingredient is to define a method:
```@example
function ClimaCore.DebugOnly.post_op_callback(result, args...; kwargs...)
    if any(isnan, parent(result))
        println("NaNs found!")
    end
end
```
If needed, `post_op_callback` can be specialized or behave differently in
different cases, but here, it only checks if `NaN`s are in the given that.

Note that, due to dispatch, `post_op_callback` will likely need a very general
method signature, and using `post_op_callback
(result::DataLayouts.VIJFH, args...; kwargs...)` above fails (on the CPU),
because `post_op_callback` ends up getting called multiple times with different
datalayouts.

Now, let us put everything together and demonstrate a complete example:

```@example
import ClimaCore
ClimaCore.DebugOnly.call_post_op_callback() = true
function ClimaCore.DebugOnly.post_op_callback(result, args...; kwargs...)
    if any(isnan, parent(result))
        println("NaNs found!")
    end
end

FT = Float64
data = ClimaCore.DataLayouts.VIJFH{FT}(Array{FT}, zeros; Nv=5, Nij=2, Nh=2)
@. data = NaN
```
This example should print `NaN` on your standard output.

### Infiltrating

[Infiltrator.jl](https://github.com/JuliaDebug/Infiltrator.jl) is a simple
debugging tool for Julia packages.

!!! warn

    While this debugging tool may be helpful, it's not bullet proof. NaNs can
    infiltrate user data any time internals are used. For example `parent
    (data) .= NaN` will not be caught by ClimaCore.DebugOnly, and errors can be
    observed later than expected.

!!! note

    This method is called in many places, so this is a performance-critical code
    path and expensive operations performed in `post_op_callback` may
    significantly slow down your code.
