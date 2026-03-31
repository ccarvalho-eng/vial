defmodule Aludel.Interfaces.LLM.ErrorParserTest do
  use ExUnit.Case, async: true

  alias Aludel.Interfaces.LLM.ErrorParser

  describe "parse_error/1" do
    test "returns auth error for 401 status" do
      assert {:error, {:auth_error, "Invalid API key"}} =
               ErrorParser.parse_error(%{status: 401})
    end

    test "returns rate limit error for 429 status" do
      assert {:error, {:rate_limit, nil}} = ErrorParser.parse_error(%{status: 429})
    end

    test "returns invalid request error for 400 status" do
      assert {:error, {:invalid_request, "Invalid request"}} =
               ErrorParser.parse_error(%{status: 400})
    end

    test "returns invalid request error for 404 status" do
      assert {:error, {:invalid_request, "Invalid request"}} =
               ErrorParser.parse_error(%{status: 404})
    end

    test "returns api error for other HTTP status codes" do
      error = %{status: 500, body: "Internal server error"}

      assert {:error, {:api_error, 500, inspected}} = ErrorParser.parse_error(error)
      assert inspected =~ "500"
      assert inspected =~ "Internal server error"
    end

    test "returns network error for non-HTTP errors" do
      assert {:error, {:network_error, :timeout}} =
               ErrorParser.parse_error(:timeout)

      assert {:error, {:network_error, :econnrefused}} =
               ErrorParser.parse_error(:econnrefused)
    end
  end
end
