defmodule Vial.Web.Helpers do
  @moduledoc false

  alias Phoenix.VerifiedRoutes

  @doc """
  Construct a path to a dashboard page with optional params.

  Routing is based on a socket and prefix tuple stored in the process dictionary.
  """
  def vial_path(route, params \\ %{})

  def vial_path(route, params) when is_list(route) do
    route
    |> Enum.join("/")
    |> vial_path(params)
  end

  def vial_path(route, params) do
    params =
      params
      |> Enum.sort()
      |> encode_params()

    case Process.get(:routing) do
      {socket, prefix} ->
        VerifiedRoutes.unverified_path(socket, socket.router, "#{prefix}/#{route}", params)

      :nowhere ->
        "/"

      nil ->
        raise RuntimeError, "nothing stored in the :routing key"
    end
  end

  defp encode_params([]), do: []

  defp encode_params(params) do
    for {key, value} <- params do
      cond do
        is_list(value) -> {key, Enum.join(value, ",")}
        true -> {key, value}
      end
    end
  end
end
