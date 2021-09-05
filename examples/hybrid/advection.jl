push!(LOAD_PATH, joinpath(@__DIR__, "..", ".."))

using Test
using StaticArrays, IntervalSets, LinearAlgebra

import ClimaCore:
    ClimaCore,
    slab,
    Spaces,
    Domains,
    Meshes,
    Geometry,
    Topologies,
    Spaces,
    Fields,
    Operators
import ClimaCore.Domains.Geometry

# set up function space
function hvspace_2D()
    FT = Float64
    vertdomain =
        Domains.IntervalDomain(FT(-1), FT(1); x3boundary = (:bottom, :top))
    vertmesh = Meshes.IntervalMesh(vertdomain, nelems = 64)
    vert_center_space = Spaces.CenterFiniteDifferenceSpace(vertmesh)
    vert_face_space = Spaces.FaceFiniteDifferenceSpace(vert_center_space)

    horzdomain = Domains.RectangleDomain(
        -1..1,
        -0..0,
        x1periodic = true,
        x2boundary = (:a, :b),
    )
    horzmesh = Meshes.EquispacedRectangleMesh(horzdomain, 10, 1)
    horztopology = Topologies.GridTopology(horzmesh)

    quad = Spaces.Quadratures.GLL{8}()
    horzspace = Spaces.SpectralElementSpace1D(horztopology, quad)

    hv_center_space =
        Spaces.ExtrudedFiniteDifferenceSpace(horzspace, vert_center_space)
    hv_face_space = Spaces.FaceExtrudedFiniteDifferenceSpace(hv_center_space)

    return (hv_center_space, hv_face_space)
end

# set up rhs!
hv_center_space, hv_face_space = hvspace_2D()

w =
    Geometry.Cartesian13Vector.(
        zeros(Float64, hv_face_space),
        ones(Float64, hv_face_space),
    )
uₕ = Geometry.Cartesian1Vector.(ones(Float64, hv_center_space),)

function rhs!(dY, Y, _, t)
    h = Y.h
    dh = dY.h

    # vertical advection
    Ic2f = Operators.InterpolateC2F(top = Operators.Extrapolate())
    divf2c = Operators.DivergenceF2C(
        bottom = Operators.SetValue(Geometry.Cartesian13Vector(0.0, 0.0)),
    )
    @. dh = -divf2c(w ⊗ Ic2f(h))

    # horizontal advection
    hdiv = Operators.Divergence()
    @. dh -= hdiv(h * uₕ)
    Spaces.weighted_dss!(dh)

    return dY
end

# initial conditions
coords = Fields.coordinate_field(hv_center_space)
h = map(coords) do coord
    Geometry.Cartesian1Vector(exp(-((coord.x + 0.5)^2 + (coord.z + 0.5)^2) / (2 * 0.2^2)))
end
Y = Fields.FieldVector(h = h)

# run!
using OrdinaryDiffEq
Δt = 0.01
prob = ODEProblem(rhs!, Y, (0.0, 1.0))
sol = solve(prob, SSPRK33(), dt = Δt, saveat = 0.05);

# post-processing
using Plots
Plots.png(Plots.plot(sol.u[1].h), "initial.png")
Plots.png(Plots.plot(sol.u[end].h), "final.png")

anim = Plots.@animate for u in sol.u
    Plots.plot(u.h, clim = (0, 1))
end
Plots.mp4(anim, "movie.mp4", fps = 10)
