defmodule Vial.Web.Layouts do
  @moduledoc false
  use Phoenix.Component

  embed_templates "layouts/*"

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full bg-gray-100">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Vial Dashboard</title>
        <link rel="stylesheet" href={"/css-#{asset_hash(:css)}"} />
        <script src={"/js-#{asset_hash(:js)}"} defer>
        </script>
      </head>
      <body class="h-full">
        {@inner_content}
      </body>
    </html>
    """
  end

  defp asset_hash(:css), do: "9561d988"
  defp asset_hash(:js), do: "4a88baa4"
end
