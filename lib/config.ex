defmodule EctoShorts.Config do
  @app :ecto_shorts

  def repo do
    Application.get_env(@app, :repo)
  end

  def strict? do
    Application.get_env(@app, :strict, false)
  end
end
