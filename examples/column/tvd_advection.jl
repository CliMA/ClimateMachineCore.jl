using Test
using LinearAlgebra
import ClimaComms
ClimaComms.@import_required_backends
using OrdinaryDiffEqSSPRK: ODEProblem, solve, SSPRK33
using ClimaTimeSteppers

import ClimaCore:
    Fields,
    Domains,
    Topologies,
    Meshes,
    DataLayouts,
    Operators,
    Geometry,
    Spaces


# Advection Equation, with constant advective velocity (so advection form = flux form)
# ∂_t y + w ∂_z y  = 0
# the solution translates to the right at speed w,
# so at time t, the solution is y(z - w * t)

# visualization artifacts
ENV["GKSwstype"] = "nul"
using ClimaCorePlots, Plots
Plots.GRBackend()
dir = "tvd_advection"
path = joinpath(@__DIR__, "output", dir)
mkpath(path)


function tendency!(yₜ, y, parameters, t)
    (; w, Δt, limiter_method) = parameters
    FT = Spaces.undertype(axes(y.q))
    bcvel = pulse(-π, t, z₀, zₕ, z₁)
    divf2c = Operators.DivergenceF2C(
        bottom = Operators.SetValue(Geometry.WVector(FT(bcvel))),
        top = Operators.SetValue(Geometry.WVector(FT(0))),
    )
    upwind1 = Operators.UpwindBiasedProductC2F(
        bottom = Operators.Extrapolate(),
        top = Operators.Extrapolate(),
    )
    upwind3 = Operators.Upwind3rdOrderBiasedProductC2F(
        bottom = Operators.ThirdOrderOneSided(),
        top = Operators.ThirdOrderOneSided(),
    )
    LimitedFlux = Operators.TVDSlopeLimitedFlux(
        bottom = Operators.FirstOrderOneSided(),
        top = Operators.FirstOrderOneSided(),
        method = limiter_method,
    )
    If = Operators.InterpolateC2F()
    @. yₜ.q =
        -divf2c(
            upwind1(w, y.q) +
            LimitedFlux(upwind3(w, y.q) - upwind1(w, y.q), y.q / Δt),
        )
    # @. yₜ.q =
    #     -divf2c(w * If(y.q))
end

# Define a pulse wave or square wave

FT = Float64
t₀ = FT(0.0)
Δt = 0.0001 * 25
t₁ = 200Δt
z₀ = FT(0.0)
zₕ = FT(1.0)
z₁ = FT(1.0)
speed = FT(-1.0)
pulse(z, t, z₀, zₕ, z₁) = abs(z - speed * t) ≤ zₕ ? z₁ : z₀

n = 2 .^ 6

domain = Domains.IntervalDomain(
    Geometry.ZPoint{FT}(-π),
    Geometry.ZPoint{FT}(π);
    boundary_names = (:bottom, :top),
)

stretch_fns = (Meshes.Uniform(), Meshes.ExponentialStretching(FT(7.0)))
plot_string = ["uniform", "stretched"]

for (i, stretch_fn) in enumerate(stretch_fns)
    limiter_methods = (
        Operators.RZeroLimiter(),
        Operators.RHalfLimiter(),
        Operators.RMaxLimiter(),
        Operators.MinModLimiter(),
        Operators.KorenLimiter(),
        Operators.SuperbeeLimiter(),
        Operators.MonotonizedCentralLimiter(),
        Operators.VanLeerLimiter(),
    )
    for limiter_method in limiter_methods
        @info (limiter_method, stretch_fn)
        mesh = Meshes.IntervalMesh(domain, stretch_fn; nelems = n)
        cent_space = Spaces.CenterFiniteDifferenceSpace(mesh)
        face_space = Spaces.FaceFiniteDifferenceSpace(cent_space)
        z = Fields.coordinate_field(cent_space).z
        O = ones(FT, face_space)

        # Initial condition
        q_init = pulse.(z, 0.0, z₀, zₕ, z₁)
        y = Fields.FieldVector(q = q_init)

        # Unitary, constant advective velocity
        w = Geometry.WVector.(speed .* O)

        # Solve the ODE
        parameters = (; w, Δt, limiter_method)
        prob = ODEProblem(
            ClimaODEFunction(; T_exp! = tendency!),
            y,
            (t₀, t₁),
            parameters,
        )
        sol = solve(
            prob,
            ExplicitAlgorithm(SSP33ShuOsher()),
            dt = Δt,
            saveat = Δt,
        )

        q_final = sol.u[end].q
        q_analytic = pulse.(z, t₁, z₀, zₕ, z₁)
        err = norm(q_final .- q_analytic)
        rel_mass_err = norm((sum(q_final) - sum(q_init)) / sum(q_init))


        plot(q_final)
        Plots.png(
            Plots.plot!(q_analytic, title = "$(typeof(limiter_method))"),
            joinpath(
                path,
                "exact_and_computed_advected_square_wave_TVDSlopeLimitedFlux_" *
                "$(nameof(typeof(limiter_method)))_" *
                plot_string[i] *
                ".png",
            ),
        )
        @test err ≤ 0.25
        @test rel_mass_err ≤ 10eps()
    end
end
