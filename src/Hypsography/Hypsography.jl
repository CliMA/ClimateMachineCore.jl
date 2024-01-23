module Hypsography

import ClimaComms, Adapt

import ..slab, ..column
import ..Geometry,
    ..DataLayouts,
    ..Domains,
    ..Topologies,
    ..Grids,
    ..Spaces,
    ..Fields,
    ..Operators
import ..Spaces: ExtrudedFiniteDifferenceSpace

import ..Grids:
    _ExtrudedFiniteDifferenceGrid,
    ExtrudedFiniteDifferenceGrid,
    HypsographyAdaption,
    Flat

using StaticArrays, LinearAlgebra


"""
    LinearAdaption(surface::Field)

Locate the levels by linear interpolation between the surface field and the top
of the domain, using the method of [GalChen1975](@cite).
"""
struct LinearAdaption{F <: Fields.Field} <: HypsographyAdaption
    surface::F
    function LinearAdaption(surface::Fields.Field)
        if eltype(surface) <: Real
            @warn "`LinearAdaptation`: `surface` argument scalar field has been deprecated. Use a field `ZPoint`s."
            surface = Geometry.ZPoint.(surface)
        end
        new{typeof(surface)}(surface)
    end
end

# this method is invoked by the ExtrudedFiniteDifferenceGrid constructor
function _ExtrudedFiniteDifferenceGrid(
    horizontal_grid::Grids.AbstractGrid,
    vertical_grid::Grids.FiniteDifferenceGrid,
    adaption::LinearAdaption,
    global_geometry::Geometry.AbstractGlobalGeometry,
)
    @assert Spaces.grid(axes(adaption.surface)) == horizontal_grid
    z_surface = Fields.field_values(adaption.surface)

    face_z_ref =
        Grids.local_geometry_data(vertical_grid, Grids.CellFace()).coordinates
    vertical_domain = Topologies.domain(vertical_grid)
    z_top = vertical_domain.coord_max

    face_z = @. Geometry.ZPoint(
        face_z_ref.z + (1 - face_z_ref.z / z_top.z) * z_surface.z,
    )

    return _ExtrudedFiniteDifferenceGrid(
        horizontal_grid,
        vertical_grid,
        adaption,
        global_geometry,
        face_z,
    )
end


"""
    SLEVEAdaption(surface::Field, ηₕ::FT, s::FT)

Locate vertical levels using an exponential function between the surface field and the top
of the domain, using the method of [Schar2002](@cite). This method is modified
such no warping is applied above some user defined parameter 0 ≤ ηₕ < 1.0, where the lower and upper
bounds represent the domain bottom and top respectively. `s` governs the decay rate.
If the decay-scale is poorly specified (i.e., `s * zₜ` is lower than the maximum
surface elevation), a warning is thrown and `s` is adjusted such that it `szₜ > maximum(z_surface)`.
"""
struct SLEVEAdaption{F <: Fields.Field, FT <: Real} <: HypsographyAdaption
    surface::F
    ηₕ::FT
    s::FT
    function SLEVEAdaption(
        surface::Fields.Field,
        ηₕ::FT,
        s::FT,
    ) where {FT <: Real}
        @assert 0 <= ηₕ <= 1
        @assert s >= 0
        if eltype(surface) <: Real
            @warn "`SLEVEAdaption`: `surface` argument scalar field has been deprecated. Use a field `ZPoint`s."
            surface = Geometry.ZPoint.(surface)
        end
        new{typeof(surface), FT}(surface, ηₕ, s)
    end
end

function _ExtrudedFiniteDifferenceGrid(
    horizontal_grid::Grids.AbstractGrid,
    vertical_grid::Grids.FiniteDifferenceGrid,
    adaption::SLEVEAdaption,
    global_geometry::Geometry.AbstractGlobalGeometry,
)
    @assert Spaces.grid(axes(adaption.surface)) == horizontal_grid
    z_surface = Fields.field_values(adaption.surface)

    face_z_ref =
        Grids.local_geometry_data(vertical_grid, Grids.CellFace()).coordinates
    vertical_domain = Topologies.domain(vertical_grid)
    z_top = vertical_domain.coord_max

    (; ηₕ, s) = adaption

    η = @. face_z_ref.z ./ z_top.z
    if s * z_top.z <= maximum(z_surface.z)
        @warn "Decay scale (s*z_top = $(s*z_top)) must be higher than max surface elevation (max(z_surface) = $(maximum(z_surface))). Returning s = FT(0.8). Scale height is therefore s=$(0.8 * z_top) m."
        s = oftype(s, 0.8)
        adaption = SLEVEAdaption(adaption.surface, ηₕ, s)
    end

    face_z = @. ifelse(
        η <= ηₕ,
        η * z_top + z_surface * (sinh((ηₕ - η) / s / ηₕ)) / (sinh(1 / s)),
        η * z_top,
    )

    return _ExtrudedFiniteDifferenceGrid(
        horizontal_grid,
        vertical_grid,
        adaption,
        global_geometry,
        face_z,
    )
end

# generic hypsography constructor, uses computed face_z points
function _ExtrudedFiniteDifferenceGrid(
    horizontal_grid::Grids.AbstractGrid,
    vertical_grid::Grids.FiniteDifferenceGrid,
    adaption::HypsographyAdaption,
    global_geometry::Geometry.AbstractGlobalGeometry,
    face_z::DataLayouts.AbstractData{Geometry.ZPoint{FT}},
) where {FT}
    # construct the "flat" grid
    # avoid cached constructor so that it gets cleaned up automatically
    flat_grid = _ExtrudedFiniteDifferenceGrid(
        horizontal_grid,
        vertical_grid,
        Flat(),
        global_geometry,
    )
    center_flat_space = Spaces.space(flat_grid, Grids.CellCenter())
    face_flat_space = Spaces.space(flat_grid, Grids.CellFace())

    # compute the "z-only local geometry" based on face z coords
    ArrayType = ClimaComms.array_type(horizontal_grid.topology)
    # currently only works on Arrays
    (center_z_local_geometry, face_z_local_geometry) = Grids.fd_geometry_data(
        Adapt.adapt(Array, face_z);
        periodic = Topologies.isperiodic(vertical_grid.topology),
    )

    center_z_local_geometry = Adapt.adapt(ArrayType, center_z_local_geometry)
    face_z_local_geometry = Adapt.adapt(ArrayType, face_z_local_geometry)

    # compute ∇Z at face and centers
    grad = Operators.Gradient()

    center_∇Z_field =
        grad.(
            Fields.Field(
                center_z_local_geometry,
                center_flat_space,
            ).coordinates.z
        )
    Spaces.weighted_dss!(center_∇Z_field)

    face_∇Z_field =
        grad.(
            Fields.Field(face_z_local_geometry, face_flat_space).coordinates.z
        )
    Spaces.weighted_dss!(face_∇Z_field)

    # construct full local geometry
    center_local_geometry =
        Geometry.product_geometry.(
            horizontal_grid.local_geometry,
            center_z_local_geometry,
            Ref(global_geometry),
            Ref(Geometry.WVector(1)) .*
            adjoint.(Fields.field_values(center_∇Z_field)),
        )
    face_local_geometry =
        Geometry.product_geometry.(
            horizontal_grid.local_geometry,
            face_z_local_geometry,
            Ref(global_geometry),
            Ref(Geometry.WVector(1)) .*
            adjoint.(Fields.field_values(face_∇Z_field)),
        )

    return ExtrudedFiniteDifferenceGrid(
        horizontal_grid,
        vertical_grid,
        adaption,
        global_geometry,
        center_local_geometry,
        face_local_geometry,
    )
end

"""
    diffuse_surface_elevation!(f::Field; κ::T, iter::Int, dt::T)

Option for 2nd order diffusive smoothing of generated terrain.
Mutate (smooth) a given elevation profile `f` before assigning the surface
elevation to the `HypsographyAdaption` type. A spectral second-order diffusion
operator is applied with forward-Euler updates to generate
profiles for each new iteration. Steps to generate smoothed terrain (
represented as a ClimaCore Field) are as follows:
- Compute discrete elevation profile f
- Compute diffuse_surface_elevation!(f, κ, iter). f is mutated.
- Define `Hypsography.LinearAdaption(f)`
- Define `ExtrudedFiniteDifferenceSpace` with new surface elevation.
Default diffusion parameters are appropriate for spherical arrangements.
For `zmax-zsfc` == 𝒪(10^4), κ == 𝒪(10^8), dt == 𝒪(10⁻¹).
"""
function diffuse_surface_elevation!(
    f::Fields.Field;
    κ::T = 1e8,
    maxiter::Int = 100,
    dt::T = 1e-1,
) where {T}
    # Define required ops
    wdiv = Operators.WeakDivergence()
    grad = Operators.Gradient()
    FT = eltype(f)
    # Create dss buffer
    ghost_buffer = (bf = Spaces.create_dss_buffer(f),)
    # Apply smoothing
    for iter in 1:maxiter
        # Euler steps
        χf = @. wdiv(grad(f))
        Spaces.weighted_dss!(χf, ghost_buffer.bf)
        @. f += κ * dt * χf
    end
    # Return mutated surface elevation profile
    return f
end

function reconstruct_metric(
    ∂x∂ξ::Geometry.Axis2Tensor{
        T,
        Tuple{Geometry.UWAxis, Geometry.Covariant13Axis},
    },
    ∇z::Geometry.Covariant1Vector,
    Δz::Real,
) where {T}
    v∂x∂ξ = Geometry.components(∂x∂ξ)
    v∇z = Geometry.components(∇z)
    Geometry.AxisTensor(axes(∂x∂ξ), @SMatrix [
        v∂x∂ξ[1, 1] 0
        v∇z[1] Δz
    ])
end

function reconstruct_metric(
    ∂x∂ξ::Geometry.Axis2Tensor{
        T,
        Tuple{Geometry.UVWAxis, Geometry.Covariant123Axis},
    },
    ∇z::Geometry.Covariant12Vector,
    Δz::Real,
) where {T}
    v∂x∂ξ = Geometry.components(∂x∂ξ)
    v∇z = Geometry.components(∇z)
    Geometry.AxisTensor(
        axes(∂x∂ξ),
        @SMatrix [
            v∂x∂ξ[1, 1] v∂x∂ξ[1, 2] 0
            v∂x∂ξ[2, 1] v∂x∂ξ[2, 2] 0
            v∇z[1] v∇z[2] Δz
        ]
    )
end

end
