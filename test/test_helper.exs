ExUnit.start()

{:ok, _} = Application.ensure_all_started(:postgrex)

{:ok, _} = EctoShorts.Repo.start_link()
