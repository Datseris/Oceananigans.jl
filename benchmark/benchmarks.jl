using BenchmarkTools, Printf, Statistics

using Oceananigans, Oceananigans.Operators

# Pretty printing functions stolen from BenchmarkTools.jl
prettypercent(p) = string(@sprintf("%.2f", p * 100), "%")

function prettydiff(p)
    diff = p - 1.0
    return string(diff >= 0.0 ? "+" : "", @sprintf("%.2f", diff * 100), "%")
end

function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(@sprintf("%.3f", value), " ", units)
end

function prettymemory(b)
    if b < 1024
        return string(b, " bytes")
    elseif b < 1024^2
        value, units = b / 1024, "KiB"
    elseif b < 1024^3
        value, units = b / 1024^2, "MiB"
    else
        value, units = b / 1024^3, "GiB"
    end
    return string(@sprintf("%.2f", value), " ", units)
end

function pretty_print_summary(b, func_name)
    print("|",
          lpad(func_name, 14), " │",
          lpad(prettymemory(b.memory), 11), " │",
          lpad(b.allocs, 9), " │",
          lpad(prettytime(minimum(b.times)), 10), " │",
          lpad(prettytime(median(b.times)), 10), " │",
          lpad(prettytime(mean(b.times)), 10), " │",
          lpad(prettytime(maximum(b.times)), 10), " │",
          lpad(b.params.samples, 8), " │",
          lpad(b.params.evals, 6), " │"
          )

    if !(median(b.gctimes) ≈ 0)
        print(" GC min: ", prettypercent(100 * minimum(b.gctimes) / minimum(b.times)), ", ",
              " GC med: ", prettypercent(100 * median(b.gctimes) / median(b.times)), "\n"
              )
    else
        print("\n")
    end
end

function run_benchmarks()
    N = (100, 100, 100)
    L = (1000, 1000, 1000)
    T = Float64

    g = RegularCartesianGrid(N, L, T)
    ũ = VelocityFields(g)
    t̃ = TemporaryFields(g)

    ũ.u.data .= rand(T, size(g))
    ũ.v.data .= rand(T, size(g))
    ũ.w.data .= rand(T, size(g))

    #print("+---------------------------------------------------------------------------------------------------------+\n")
    # print("| ", rpad(" BENCHMARKING OCEANANIGANS: T=$T, (Nx, Ny, Nz)=$N", 103), " |\n")
    # print("+---------------+------------+----------+-----------+-----------+-----------+-----------+---------+-------+\n")
    # print("| function name |   memory   |  allocs  | min. time | med. time | mean time | max. time | samples | evals |\n")

    print("┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐\n")
    print("│ ", rpad(" BENCHMARKING OCEANANIGANS: T=$T (Nx, Ny, Nz) = $N", 103), " │\n")
    print("├───────────────┬────────────┬──────────┬───────────┬───────────┬───────────┬───────────┬─────────┬───────┤\n")
    print("│ function name │   memory   │  allocs  │ min. time │ med. time │ mean time │ max. time │ samples │ evals │\n")

    b = @benchmark δx!($g, $ũ.u, $t̃.fC1); pretty_print_summary(b, "δx! f⟶c");
    b = @benchmark δx!($g, $t̃.fC1, $ũ.u); pretty_print_summary(b, "δx! c⟶f");

    b = @benchmark rand(55, 55, 55)
    pretty_print_summary(b, "rand(55^3)")

    # print("+---------------------------------------------------------------------------------------------------------+\n")
    print("└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘\n")
end
