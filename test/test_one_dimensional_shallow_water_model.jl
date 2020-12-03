# # One dimensional shallow water example

using Oceananigans
using Oceananigans.Models: ShallowWaterModel
using Oceananigans.Grids: Periodic, Bounded

grid = RegularCartesianGrid(size=(64, 1, 1), extent=(10, 1, 1), topology=(Periodic, Bounded, Bounded))

model = ShallowWaterModel(        grid = grid,
                          architecture = CPU(),
                             advection = nothing, 
                              coriolis = FPlane(f=0.0)
                                  )

width = 0.3
 h(x, y, z)  = 1.0 + 0.1 * exp(-(x - 5)^2 / (2width^2));  
uh(x, y, z) = 0.0
vh(x, y, z) = 0.0 

set!(model, uh = uh, vh = vh, h = h)

simulation = Simulation(model, Δt = 0.01, stop_iteration = 500)



using Plots
using Oceananigans.Grids: xnodes 

x = xnodes(model.solution.h);

h_plot = plot(x, interior(model.solution.h)[:, 1, 1],
              linewidth = 2,
              label = "t = 0",
              xlabel = "x",
              ylabel = "height")


using Oceananigans.OutputWriters: JLD2OutputWriter, IterationInterval

simulation.output_writers[:height] =
    JLD2OutputWriter(model, model.solution, prefix = "one_dimensional_wave_equation",
                     schedule=IterationInterval(1), force = true)



run!(simulation)


using Printf

plt = plot!(h_plot, x, interior(model.solution.h)[:, 1, 1], linewidth=2,
            label=@sprintf("t = %.3f", model.clock.time))

savefig("slice")
println("Saving plot of initial and final conditions.")

using JLD2

file = jldopen(simulation.output_writers[:height].filepath)
iterations = parse.(Int, keys(file["timeseries/t"]))

time = [file["timeseries/t/$iter"] for iter in iterations]

# Build array of T(z, t)

Nx = file["grid/Nx"]
hp = zeros(Nx, length(iterations))

for (i, iter) in enumerate(iterations)
    hp[:, i] = file["timeseries/h/$iter"][:, 1, 1]
end

plt = contourf(time, x, hp, linewidth=0)

savefig("Hovmolleer")
println("Saving Hovmoller plot of the solution.")


