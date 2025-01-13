import ClimaCore
import ClimaComms
ClimaComms.@import_required_backends
using ClimaCore.CommonSpaces
using Test

@testset "High resolution spaces" begin
    kwargs = (;
        radius = 1.0,
        h_elem = 105,
        z_elem = 10,
        z_min = 1.0,
        z_max = 2.0,
        n_quad_points = 4,
        staggering = CellCenter(),
    )
    if ClimaComms.device() isa ClimaComms.CUDADevice
        @test_broken begin
            ExtrudedCubedSphereSpace(Float32; kwargs...)
        end
    else
        @test begin
            ExtrudedCubedSphereSpace(Float32; kwargs...)
            true
        end
    end
end
