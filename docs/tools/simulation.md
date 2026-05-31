# Simulation (cocotb + iverilog)

Functional verification with **cocotb** testbenches and **iverilog** simulation.

## Prerequisites

- `iverilog`, `vvp` on `PATH`
- `cocotb-config` on `PATH` (pip install cocotb)
- Project under work dir — use `depot_init` to scaffold RTL + tests

## Typical flow

1. `depot_init(project_name="my_counter", template="counter")`
2. `sim_list_tests(project_name="my_counter")`
3. `sim_run_testbench(project_name="my_counter", test_module="test_counter")`
4. `sim_read_waveform(project_name="my_counter")` — VCD summary
5. `sim_check_coverage(project_name="my_counter")` — test inventory

## Tools

| Tool | Mutating | Description |
|------|----------|-------------|
| `sim_list_tests` | No | Discover cocotb test modules |
| `sim_run_testbench` | Yes | Run iverilog + cocotb (may write VCD) |
| `sim_read_waveform` | No | Parse VCD in project dir |
| `sim_check_coverage` | No | List test functions in test files |

## Gotchas

- iverilog has **limited SystemVerilog** — use Verilog-2001 style for compatibility
- Simulation cwd is the project directory created by `depot_init`
- Failures return stderr from iverilog/cocotb in the tool result

## Example prompts

- "Create a counter project, list tests, and run the basic cocotb test."
- "Read the waveform after simulation and summarize signal toggles."

## Related

- [depot.md](depot.md) — project templates
- [synthesis.md](synthesis.md) — after RTL sim passes
