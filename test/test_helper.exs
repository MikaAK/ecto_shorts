ExUnit.start()

{:ok, _} = Application.ensure_all_started(:postgrex)

{:ok, _} = EctoShorts.Support.Repo.start_link()

if System.get_env("CI") do
  Code.put_compiler_option(:warnings_as_errors, true)
end
