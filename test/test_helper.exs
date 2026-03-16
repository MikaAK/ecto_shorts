# Code.put_compiler_option(:warnings_as_errors, true)

ExUnit.start()

{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = EctoShorts.Repo.start_link()
