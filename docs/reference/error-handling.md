# Error Handling in EctoShorts

EctoShorts provides a standardized approach to error handling using the `ErrorMessage` struct from the [elixir_error_message](https://github.com/MikaAK/elixir_error_message) package. This ensures consistent error representation throughout your application.

## ErrorMessage Structure

The `ErrorMessage` struct has the following structure:

```elixir
%ErrorMessage{
  code: :error_code,        # An atom representing the error type
  message: "Error message", # A human-readable error message
  details: %{...}           # A map containing additional context
}
```

## Standard Error Codes

EctoShorts uses the following standard error codes:

| Code | Description | HTTP Status Code |
|------|-------------|-----------------|
| `:not_found` | The requested resource could not be found | 404 |
| `:bad_request` | The request contains invalid parameters | 400 |
| `:internal_server_error` | An unexpected error occurred | 500 |
| `:unauthorized` | Authentication is required | 401 |
| `:forbidden` | The user lacks permission | 403 |

## Error Examples

### Not Found Error

When a record cannot be found:

```elixir
{:error, %ErrorMessage{
  code: :not_found,
  message: "Record not found",
  details: %{id: 123, schema: "User"}
}}
```

### Validation Error

For validation errors, EctoShorts returns the Ecto changeset directly:

```elixir
{:error, %Ecto.Changeset{...}}
```

### Bad Request Error

When invalid parameters are provided:

```elixir
{:error, %ErrorMessage{
  code: :bad_request,
  message: "Invalid parameters",
  details: %{invalid_params: [:email, :age]}
}}
```

## Handling Errors

Here's how to handle errors in your application code:

```elixir
case EctoShorts.Actions.get(User, id) do
  {:ok, user} -> 
    # Process the user
    
  {:error, %ErrorMessage{code: :not_found}} -> 
    # Handle not found error
    
  {:error, %ErrorMessage{code: :bad_request}} -> 
    # Handle bad request error
    
  {:error, %Ecto.Changeset{} = changeset} -> 
    # Handle validation errors
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} -> 
      Enum.reduce(opts, msg, fn {key, value}, acc -> 
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    # Use the errors map
end
```

## Custom Error Handling

You can customize error handling by configuring a custom error module:

```elixir
# In your config.exs
config :ecto_shorts, :error_module, YourApp.CustomErrorModule
```

Your custom module must implement the `create_error/3` callback:

```elixir
defmodule YourApp.CustomErrorModule do
  @behaviour EctoShorts.Actions.Error
  
  @impl true
  def create_error(code, message, details) do
    # Your custom error creation logic
    %ErrorMessage{
      code: code,
      message: message,
      details: Map.merge(details, %{app_name: "YourApp"})
    }
  end
end
```

## Integration with Phoenix Controllers

When using EctoShorts with Phoenix, you can leverage the ErrorMessage structure for consistent API responses:

```elixir
def show(conn, %{"id" => id}) do
  case MyApp.Accounts.get_user(id) do
    {:ok, user} -> 
      render(conn, :show, user: user)
      
    {:error, %ErrorMessage{code: :not_found}} -> 
      conn
      |> put_status(:not_found)
      |> json(%{error: "User not found"})
      
    {:error, %ErrorMessage{} = error} ->
      status = ErrorMessage.http_code(error)
      conn
      |> put_status(status)
      |> json(%{
        error: error.message,
        details: error.details
      })
  end
end
```

## Benefits of Using ErrorMessage

1. **Consistency** - All errors follow the same structure
2. **Rich context** - Errors contain detailed information to help with debugging
3. **HTTP integration** - Easy mapping to HTTP status codes
4. **Serialization** - ErrorMessage provides helpers for converting to strings and JSON
5. **Extensibility** - Custom error modules allow for application-specific error handling
