import ClimaCore
center_space = ClimaCore.CommonSpaces.ExtrudedCubedSphereSpace(
    Float32;
    radius = 1.0,
    h_elem = 105,
    z_elem = 10,
    z_min = 1.0,
    z_max = 2.0,
    n_quad_points = 4,
    staggering = ClimaCore.Grids.CellCenter(),
)
