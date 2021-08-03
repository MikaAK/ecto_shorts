defmodule EctoShorts.Config do
  @app :ecto_shorts

  def get_default_repo do
    Application.get_env(@app, :repo)
  end
end
