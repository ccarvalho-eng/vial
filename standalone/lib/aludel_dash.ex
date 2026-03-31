defmodule AludelDash.Repo do
  use Ecto.Repo, otp_app: :aludel_dash, adapter: Ecto.Adapters.Postgres
end

defmodule AludelDash.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule AludelDash.BasicAuth do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Application.get_env(:aludel_dash, :basic_auth_user)
    pass = Application.get_env(:aludel_dash, :basic_auth_pass)

    if user && pass do
      authenticate(conn, user, pass)
    else
      conn
    end
  end

  defp authenticate(conn, user, pass) do
    with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         ^decoded <- "#{user}:#{pass}" do
      conn
    else
      _ ->
        conn
        |> put_resp_header("www-authenticate", ~s(Basic realm="Aludel Dashboard"))
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end

defmodule AludelDash.Resolver do
  @behaviour Aludel.Web.Resolver

  @impl true
  def resolve_user(_conn), do: nil

  @impl true
  def resolve_access(_user) do
    if Application.get_env(:aludel_dash, :read_only, false) do
      :read_only
    else
      :all
    end
  end

  @impl true
  def resolve_refresh(_user), do: 5
end

defmodule AludelDash.Router do
  use Phoenix.Router, helpers: false

  import Aludel.Web.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(AludelDash.BasicAuth)
  end

  scope "/" do
    pipe_through(:browser)

    aludel_dashboard("/", resolver: AludelDash.Resolver)
  end
end

defmodule AludelDash.Endpoint do
  use Phoenix.Endpoint, otp_app: :aludel_dash

  socket("/live", Phoenix.LiveView.Socket)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Session,
    store: :cookie,
    key: "_aludel_dash_key",
    signing_salt: "aludel_dashboard"
  )

  plug(AludelDash.Router)
end

defmodule AludelDash.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AludelDash.Repo,
      {Phoenix.PubSub, name: AludelDash.PubSub},
      AludelDash.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AludelDash.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
