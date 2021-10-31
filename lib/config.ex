defmodule EctoShorts.Config do
  @app :ecto_shorts

  def get_default_opts do
    [
      repo: Application.get_env(@app, :repo)
    ]
  end
end
