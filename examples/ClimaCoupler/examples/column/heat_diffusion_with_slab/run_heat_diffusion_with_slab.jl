using Base: show_supertypes
#push!(LOAD_PATH, joinpath(@__DIR__, "..", ".."))

# add https://github.com/CliMA/ClimaCore.jl
# import required modules
import ClimaCore.Geometry, LinearAlgebra, UnPack
import ClimaCore:
    Fields,
    Domains,
    Topologies,
    Meshes,
    DataLayouts,
    Operators,
    Geometry,
    Spaces

using OrdinaryDiffEq: ODEProblem, solve, SSPRK33

using Logging: global_logger
using TerminalLoggers: TerminalLogger

using RecursiveArrayTools

using OrdinaryDiffEq, Test, Random
#using DiffEqProblemLibrary.ODEProblemLibrary: importodeproblems; importodeproblems()
#import DiffEqProblemLibrary.ODEProblemLibrary: prob_ode_linear

global_logger(TerminalLogger())

const CI = !isnothing(get(ENV, "CI", nothing))

# general parameters
const FT = Float64

# coupling parameters
λ = FT(1e-5) # transfer coefficient
calculate_flux(T_sfc, T1) = λ .* (T_sfc .- T1)

# domain parameters
zmin_atm = FT(0.0)
zmax_atm = FT(1.0)
zmin_lnd = FT(-1.0)
zmax_lnd = FT(0.0)

n = 15

# initiate model domain and grid
domain_atm  = Domains.IntervalDomain(zmin_atm, zmax_atm, x3boundary = (:bottom, :top)) # struct
#domain_lnd  = Domains.IntervalDomain(zmin_lnd, zmax_lnd, x3boundary = (:bottom, :top)) # struct

mesh_atm = Meshes.IntervalMesh(domain_atm, nelems = n) # struct, allocates face boundaries to 5,6: atmos
#mesh_lnd = Meshes.IntervalMesh(domain_lnd, nelems = 1) # struct, allocates face boundaries to 5,6: land

cs_atm = Spaces.CenterFiniteDifferenceSpace(mesh_atm) # collection of the above, discretises space into FD and provides coords
#cs_lnd = Spaces.CenterFiniteDifferenceSpace(mesh_lnd)

# define model equations:
function ∑tendencies_atm!(du, u, (parameters, T_sfc), t)
    # Heat diffusion:
    # ∂_t T = α ∇²T
    # where
    # ∂_t T = n \cdot F   at z = zmin_atm
    # ∂_t T = 0           at z = zmax_atm
    # We also use this model to accumulate fluxes
    # ∂_t ϕ_bottom = n \cdot F

    μ = FT(0.0001) # diffusion coefficient

    T = u.x[1]

    F_sfc = - calculate_flux( T_sfc[1], parent(T)[1] )
    
    # set BCs
    bcs_bottom = Operators.SetValue(F_sfc) # struct w bottom BCs
    bcs_top = Operators.SetValue(FT(280.0))

    gradc2f = Operators.GradientC2F(top = bcs_top) # gradient struct w BCs
    gradf2c = Operators.GradientF2C(bottom = bcs_bottom)

    # tendency calculations
    @. du.x[1] = gradf2c( μ * gradc2f(T))
    du.x[2] .= - F_sfc[1]

end

function ∑tendencies_lnd!(dT_sfc, T_sfc, (parameters, F_sfc), t)
    """
    Slab ocean:
    ∂_t T_sfc = F_sfc + G
    """
    G = 0.0 # place holder for soil dynamics

    @. dT_sfc = F_sfc + G
end

# initialize all variables and display models
parameters = nothing
T_atm_0 = Fields.ones(FT, cs_atm) .* 280 # initiates atm progostic var
T_lnd_0 = [260.0] # initiates lnd progostic var
ics = (;
        atm = T_atm_0,
        lnd = T_lnd_0
        )

# specify timestepping info
stepping = (;
        Δt_min = 0.02,
        timerange = (0.0, 6.0),
        Δt_cpl = 1.0,
        odesolver = SSPRK33(),
        nsteps_atm = 4,
        nsteps_lnd = 1,
        )

# coupler comm functions which export / import / transform variables
coupler_get(x) = x
coupler_put(x) = x

# Solve the ODE operator
function coupler_solve!(stepping, ics, parameters)
    t = 0.0
    Δt_min  = stepping.Δt_min
    Δt_cpl  = stepping.Δt_cpl
    t_start = stepping.timerange[1]
    t_end   = stepping.timerange[2]

    # init coupler fields
    coupler_F_sfc = [0.0]
    coupler_T_lnd = copy(ics.lnd)

    # atmos copies of coupler variables
    atm_T_lnd = copy(coupler_T_lnd)
    atm_F_sfc = copy(coupler_F_sfc)

    # SETUP ATMOS
    # put all prognostic variable arrays into a vector and ensure that solve can partition them
    T_atm = ics.atm
    Y_atm = ArrayPartition((T_atm, atm_F_sfc))
    prob_atm = ODEProblem(∑tendencies_atm!, Y_atm, (t_start, t_end), (parameters, atm_T_lnd))
    integ_atm = init(
                        prob_atm,
                        stepping.odesolver,
                        dt = Δt_min,
                        saveat = 10 * Δt_min,)

    # land copies of coupler variables
    T_lnd = ics.lnd
    lnd_F_sfc = copy(coupler_F_sfc)

    # SETUP LAND
    prob_lnd = ODEProblem(∑tendencies_lnd!, T_lnd, (t_start, t_end), (parameters, lnd_F_sfc))
    integ_lnd = init(
                        prob_lnd,
                        stepping.odesolver,
                        dt = Δt_min,
                        saveat = 10 * Δt_min,)

    # coupler stepping
    for t in (t_start : Δt_cpl : t_end)

        ## Atmos
         # pre_atmos
         integ_atm.p[2] .= coupler_get(coupler_T_lnd)
         integ_atm.u.x[2] .= [0.0] # surface flux to be accumulated

         # run atmos
         # NOTE: use (t - integ_atm.t) here instead of Δt_cpl to avoid accumulating roundoff error in our timestepping.
         step!(integ_atm, t - integ_atm.t, true)

         # post_atmos
         # negate sign
         coupler_F_sfc .= -coupler_put(integ_atm.u.x[2]) / Δt_cpl

        ## Land
        # pre_land
        
        lnd_F_sfc .= coupler_get(coupler_F_sfc)
        
        # run land
        step!(integ_lnd, t - integ_lnd.t, true)

        # post land
        coupler_T_lnd .= coupler_put(integ_lnd.u) # update T_sfc
    end

    return integ_atm, integ_lnd
end


# run
integ_atm, integ_lnd = coupler_solve!(stepping, ics, parameters)
sol_atm, sol_lnd = integ_atm.sol, integ_lnd.sol

ENV["GKSwstype"] = "nul"
import Plots
Plots.GRBackend()

dirname = "heat"
path = joinpath(@__DIR__, "output", dirname)
mkpath(path)

anim = Plots.@animate for u in sol_atm.u
    Plots.plot(u.x[1], xlim=(220,280))
end
Plots.mp4(anim, joinpath(path, "heat.mp4"), fps = 10)
Plots.png(Plots.plot(sol_atm.u[end].x[1] ), joinpath(path, "T_atm_end.png"))

atm_sfc_u_t = [parent(u.x[1])[1] for u in sol_atm.u]
Plots.png(Plots.plot(sol_atm.t, atm_sfc_u_t), joinpath(path, "T_atmos_surface_time.png"))

lnd_sfc_u_t = [u[1] for u in sol_lnd.u]
Plots.png(Plots.plot(sol_lnd.t, lnd_sfc_u_t), joinpath(path, "T_land_surface_time.png"))

atm_sum_u_t = [sum(parent(u.x[1])[:]) for u in sol_atm.u] ./ n

v1 = lnd_sfc_u_t .- lnd_sfc_u_t[1] 
v2 = atm_sum_u_t .- atm_sum_u_t[1] 
Plots.png(Plots.plot(sol_lnd.t, [v1 v2 v1+v2], labels = ["lnd" "atm" "tot"]), joinpath(path, "heat_both_surface_time.png"))
Plots.png(Plots.plot(sol_lnd.t, [v1+v2], labels = ["tot"]), joinpath(path, "heat_total_surface_time.png"))


function linkfig(figpath, alt = "")
    # buildkite-agent upload figpath
    # link figure in logs if we are running on CI
    if get(ENV, "BUILDKITE", "") == "true"
        artifact_url = "artifact://$figpath"
        print("\033]1338;url='$(artifact_url)';alt='$(alt)'\a\n")
    end
end

linkfig("output/$(dirname)/heat_end.png", "Heat End Simulation")

# TODO
# - add flux accumulation ()®ecursive array error

# Questions / Comments
# - ok to add bottom flux as prognostic variable again?
# - MPIStateArray overhead issue doesn't apply
# - coupler src code can still be used, ust the do_step function needs to be rewritten
# - quite hard to find original functions e.g. which solve etc
# - extracting values from individual levels is quite clunky
# - Fields don't seem to contain variable names... (maybe?)

# Refs:

# ODEProblem(f,u0,tspan; _..) https://diffeq.sciml.ai/release-2.1/types/ode_types.html
    # ~/.julia/packages/DiffEqBase/NarCz/src/solve.jl:66
    # for options for solve, see: https://diffeq.sciml.ai/stable/basics/common_solver_opts/