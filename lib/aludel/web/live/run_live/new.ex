defmodule Aludel.Web.RunLive.New do
  @moduledoc """
  LiveView for configuring and launching runs.

  Allows users to fill in variable values for a prompt version,
  select providers, and execute the run.
  """

  use Aludel.Web, :live_view

  alias Aludel.Prompts
  alias Aludel.Providers
  alias Aludel.Runs
  alias Aludel.Runs.Run

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, url, socket) when map_size(params) == 0 do
    # Parse query params from URL since they weren't provided
    uri = URI.parse(url)

    if uri.query do
      handle_params(URI.decode_query(uri.query), url, socket)
    else
      {:noreply,
       socket
       |> put_flash(:error, "Missing required parameter: version")
       |> push_navigate(to: aludel_path("/prompts"))}
    end
  end

  def handle_params(%{"version" => version_id}, _url, socket) do
    prompt_version = Prompts.get_prompt_version!(version_id)
    providers = Providers.list_providers()

    variable_values =
      Map.new(prompt_version.variables, fn var -> {var, ""} end)

    changeset =
      Runs.change_run(%Run{}, %{
        prompt_version_id: version_id,
        variable_values: variable_values,
        provider_ids: []
      })

    {:noreply,
     socket
     |> assign(:page_title, "New Run")
     |> assign(:prompt_version, prompt_version)
     |> assign(:prompt, prompt_version.prompt)
     |> assign(:variables, prompt_version.variables)
     |> assign(:providers, providers)
     |> assign(:form, to_form(changeset))
     |> assign(:variable_values, variable_values)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"run" => run_params}, socket) do
    variable_values = Map.get(run_params, "variable_values", %{})
    provider_ids = normalize_provider_ids(Map.get(run_params, "provider_ids", []))

    changeset =
      %Run{}
      |> Runs.change_run(%{
        "name" => Map.get(run_params, "name", ""),
        "prompt_version_id" => socket.assigns.prompt_version.id,
        "variable_values" => variable_values,
        "provider_ids" => provider_ids
      })
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:variable_values, variable_values)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"run" => run_params}, socket) do
    provider_ids = normalize_provider_ids(Map.get(run_params, "provider_ids", []))
    variables_map = Map.get(run_params, "variable_values", %{})

    errors = validate_run_params(socket.assigns.variables, variables_map, provider_ids)

    if errors == [] do
      create_and_execute_run(socket, run_params, provider_ids)
    else
      {:noreply, put_flash(socket, :error, Enum.join(errors, ", "))}
    end
  end

  defp validate_run_params(required_variables, variables_map, provider_ids) do
    errors = []

    errors =
      if provider_ids == [] do
        ["Please select at least one provider" | errors]
      else
        errors
      end

    errors =
      Enum.reduce(required_variables, errors, fn var, acc ->
        value = Map.get(variables_map, var, "")

        if value == "" do
          ["Variable '#{var}' can't be blank" | acc]
        else
          acc
        end
      end)

    errors
  end

  defp create_and_execute_run(socket, run_params, provider_ids) do
    variables_map = Map.get(run_params, "variable_values", %{})
    name = Map.get(run_params, "name", "")

    run_attrs = %{
      prompt_version_id: socket.assigns.prompt_version.id,
      variable_values: variables_map,
      name: if(name == "", do: nil, else: name)
    }

    case Runs.create_run(run_attrs) do
      {:ok, run} ->
        providers =
          Enum.map(provider_ids, fn id ->
            Providers.get_provider!(id)
          end)

        run_with_version = %{run | prompt_version: socket.assigns.prompt_version}

        Task.start(fn ->
          Runs.execute_run(run_with_version, providers)
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Run launched successfully")
         |> push_navigate(to: aludel_path("runs/#{run.id}"))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(
           :form,
           to_form(Ecto.Changeset.put_change(changeset, :provider_ids, provider_ids))
         )
         |> assign(:variable_values, variables_map)
         |> put_flash(:error, "Failed to create run")}
    end
  end

  defp normalize_provider_ids(provider_ids) when is_list(provider_ids), do: provider_ids
  defp normalize_provider_ids(provider_id) when is_binary(provider_id), do: [provider_id]
  defp normalize_provider_ids(_), do: []
end
