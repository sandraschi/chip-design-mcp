# Depot (project scaffolding)

Create and inspect RTL + cocotb project trees under the work directory.

## Tools

| Tool | Mutating | Description |
|------|----------|-------------|
| `depot_init` | Yes | Create project from template |
| `depot_list` | No | List uploads/outputs/designs files |
| `depot_status` | No | Storage usage summary |

## Templates (`depot_init`)

| Template | Contents |
|----------|----------|
| `counter` | Simple counter RTL + cocotb tests |
| `alu` | ALU RTL + arithmetic tests |
| `fsm` | FSM RTL + sequence tests |
| `empty` | Minimal skeleton |

## Typical flow

1. `depot_init(project_name="lab1", template="counter")`
2. `depot_list(directory="designs")`
3. `sim_run_testbench(project_name="lab1", ...)`

## Gotchas

- Project names must be filesystem-safe
- Re-init may overwrite — check `depot_list` first

## Example prompts

- "Scaffold an ALU lab project and list generated files."

## Related

- [simulation.md](simulation.md)
