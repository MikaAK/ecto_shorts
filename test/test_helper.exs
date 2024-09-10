ExUnit.start()

{:ok, _} = Application.ensure_all_started(:postgrex)

{:ok, _} = EctoShorts.Support.Repo.start_link()
