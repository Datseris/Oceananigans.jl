using Oceananigans.Operators: Δzᶜᶜᶜ, Δzᶜᶜᶠ
using Oceananigans.ImmersedBoundaries: PartialCellBottom, ImmersedBoundaryGrid

"""
Update the hydrostatic pressure perturbation pHY′. This is done by integrating
the `buoyancy_perturbation` downwards:

    `pHY′ = ∫ buoyancy_perturbation dz` from `z=0` down to `z=-Lz`
"""
@kernel function _update_hydrostatic_pressure!(pHY′, offs, grid, buoyancy, C)
    i, j = @index(Global, NTuple)
    i′ = i + offs[1] 
    j′ = j + offs[2] 

    @inbounds pHY′[i′, j′, grid.Nz] = - ℑzᵃᵃᶠ(i′, j′, grid.Nz+1, grid, z_dot_g_b, buoyancy, C) * Δzᶜᶜᶠ(i′, j′, grid.Nz+1, grid)

    @unroll for k in grid.Nz-1 : -1 : 1
        @inbounds pHY′[i′, j′, k] = pHY′[i′, j′, k+1] - ℑzᵃᵃᶠ(i′, j′, k+1, grid, z_dot_g_b, buoyancy, C) * Δzᶜᶜᶠ(i′, j′, k+1, grid)
    end
end

update_hydrostatic_pressure!(model) = update_hydrostatic_pressure!(model.grid, model)
update_hydrostatic_pressure!(::AbstractGrid{<:Any, <:Any, <:Any, <:Flat}, model) = nothing
update_hydrostatic_pressure!(grid, model) = update_hydrostatic_pressure!(model.pressures.pHY′, model.architecture, model.grid, model.buoyancy, model.tracers)

# Partial cell "algorithm"
const PCB = PartialCellBottom
const PCBIBG = ImmersedBoundaryGrid{<:Any, <:Any, <:Any, <:Any, <:Any, <:PCB}

# extend p kernel to compute also the boundaries
@inline p_kernel_size(grid) = size(grid)[[1, 2]] .+ 2

update_hydrostatic_pressure!(pHY′, arch, ibg::PCBIBG, buoyancy, tracers; kernel_size = p_kernel_size(grid), kernel_offsets = (-0x1, -0x1)) =
    update_hydrostatic_pressure!(pHY′, arch, ibg.underlying_grid, buoyancy, tracers; kernel_size, kernel_offsets)

update_hydrostatic_pressure!(pHY′, arch, grid, buoyancy, tracers; kernel_size = p_kernel_size(grid), kernel_offsets = (-0x1, -0x1)) =  
        launch!(arch, grid, kernel_size, _update_hydrostatic_pressure!, pHY′, kernel_offsets, grid, buoyancy, tracers)
