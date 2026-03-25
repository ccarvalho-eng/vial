defmodule VialDash.Repo do
  use Ecto.Repo, otp_app: :vial_dash, adapter: Ecto.Adapters.Postgres
end

defmodule VialDash.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule VialDash.BasicAuth do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Application.get_env(:vial_dash, :basic_auth_user)
    pass = Application.get_env(:vial_dash, :basic_auth_pass)

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
        |> put_resp_header("www-authenticate", ~s(Basic realm="Vial Dashboard"))
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end

defmodule VialDash.Resolver do
  @behaviour Vial.Web.Resolver

  @impl true
  def resolve_user(_conn), do: nil

  @impl true
  def resolve_access(_user) do
    if Application.get_env(:vial_dash, :read_only, false) do
      :read_only
    else
      :all
    end
  end

  @impl true
  def resolve_refresh(_user), do: 5
end

defmodule VialDash.Router do
  use Phoenix.Router, helpers: false

  import Vial.Web.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(VialDash.BasicAuth)
  end

  scope "/" do
    pipe_through(:browser)

    vial_dashboard("/", resolver: VialDash.Resolver)
  end
end

defmodule VialDash.Endpoint do
  use Phoenix.Endpoint, otp_app: :vial_dash

  socket("/live", Phoenix.LiveView.Socket)

  # Serve static files from Vial's priv/static
  plug(Plug.Static,
    at: "/",
    from: {:vial, "priv/static"},
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)
  )

  plug(Plug.Session,
    store: :cookie,
    key: "_vial_dash_key",
    signing_salt: "vial_dashboard"
  )

  plug(VialDash.Router)
end

defmodule VialDash.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VialDash.Repo,
      {Phoenix.PubSub, name: VialDash.PubSub},
      VialDash.Endpoint
    ]

    opts = [strategy: :one_for_one, name: VialDash.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
