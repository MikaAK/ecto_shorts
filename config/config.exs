# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :ecto_shorts, repo: nil, error_module: EctoShorts.Actions.Error

if Mix.env() == :test do
  config :ecto_shorts, repo: EctoShorts.Repo
end
