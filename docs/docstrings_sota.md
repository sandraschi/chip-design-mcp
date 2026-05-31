# Docstring SOTA (chip-design-mcp)

Canonical fleet rules: [docstrings_sota.md](https://github.com/sandraschi/mcp-central-docs/blob/master/standards/rules/docstrings_sota.md) in **mcp-central-docs**.

## This repo

- Parameters use `Annotated[T, Field(description="...")]` — no `Args:` blocks in docstrings.
- Every tool docstring includes `## Return Format` and `## Examples`.
- Returns are `dict` with `success`, plus domain fields; errors include actionable `message` / `stderr` where applicable.
- Read-only tools use `annotations={"readonly": True}`; mutating flows use `mutating` where appropriate.
