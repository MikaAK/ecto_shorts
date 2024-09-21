defmodule EctoShorts.Utils do
  @moduledoc false

  @doc """
  Checks if the dependency version is equal to greater than the given version.

  ### Examples

      iex> EctoShorts.Utils.meets_version_requirement?(:logger, "1.11.0")
      true
  """
  @spec meets_version_requirement?(atom(), binary()) :: true | false
  def meets_version_requirement?(dep, version) do
    compare_dependency_version(dep, version) in [:eq, :gt]
  end

  @doc """
  Compares the version of a dependency.

  ### Examples

      iex> EctoShorts.Utils.compare_dependency_version(:logger, "1.11.0")
      :gt
  """
  @spec compare_dependency_version(atom(), binary()) :: :gt | :eq | :lt
  def compare_dependency_version(dep, version) do
    Application.loaded_applications()
    |> Enum.find(fn {name, _description, _version} -> name === dep end)
    |> elem(2)
    |> :binary.list_to_bin()
    |> Version.compare(version)
  end
end
