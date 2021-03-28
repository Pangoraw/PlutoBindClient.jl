# Adopted from https://discourse.julialang.org/t/get-cpu-usage/24468/2
function get_cpu_stats()
  st = read("/proc/stat", String)
  lines = split(st, "\n")
  m = map(line -> match(r"^cpu(\d) (.*)", line), lines)
  matches = filter(m -> m !== nothing, m)
  Dict(parse(Int, match.captures[1]) => parse.(Int, split(match.captures[2], ' ')) for match in matches)
end

   
cpu_percentages = Dict(i => (0, 0) for i in 0:3)
function compute_percentage(fields, cpu_idx)
  lastidle, lasttotal = cpu_percentages[cpu_idx]
  idle, total = fields[4], sum(fields)
  Δidle, Δtotal = idle - lastidle, total - lasttotal
  utilization = 100 * (1 - Δidle / Δtotal)
  cpu_percentages[cpu_idx] = idle, total
  utilization
end
