
## Use Explicit Traversal Patterns

## Rules

- Maps and Keyword lists are containers of key-value pairs and are treated the same way.
- Keyword lists are the preferred way to represent key-value pairs in this produce. Convert maps to keyword lists at the earliest possible point in the code.
- Always use explicit traversal patterns for maps and keyword lists.
- Never use pattern matching on maps and keyword lists directly.

## Examples

### Bad Examples

```elixir
# Bad Example (DO NOT DO THIS)
case entries do
  [{:field, name}] ->
    # ...
  [{:value, v}] ->
    # ...
  [{op, operands}] when op in @operand_variadic_keys ->
    # ...
  [{op, operands}] when op in @operand_binary_keys ->
    # ...
  [{op, operand}] when op in @operand_unary_keys ->
    # ...
  _ ->
    # ...
end
```

```elixir
# Bad Example (DO NOT DO THIS)
defp normalize_binary(source, op, [x, y], opts) do
  # ...
end
```

### Good Examples

```elixir

```