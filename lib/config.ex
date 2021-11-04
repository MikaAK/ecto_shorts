defmodule EctoShorts.Config do
  @app :ecto_shorts

  def repo do
    Application.get_env(@app, :repo)
  end
end
