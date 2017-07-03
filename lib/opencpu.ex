defmodule OpenCPU do
  @moduledoc """
  OpenCPU client to interact with a OpenCPU server, see https://www.opencpu.org/.
  """

  use HTTPotion.Base

  defmodule Options do
    defstruct [
      user: :system,
      data: %{},
      format: :json, # useless option now?
      github_remote: false,
      convert_na_to_nil: false
    ]
  end

  # Hook for HTTPotion
  def process_url(url) do
    case endpoint_url = get_env(:endpoint_url) do
      nil -> raise OpenCPU.OpenCPUError, message: "OpenCPU endpoint is not configured"
      _   -> endpoint_url <> url
    end
  end

  @doc """
  Execute a request on an OpenCPU server and parse the JSON result.
  """
  @spec execute(String.t, String.t, Map) :: Map
  def execute(package, function, options \\ %{}) do
    options = Map.merge(%Options{}, options)

    function_url(package, function, options.user, options.github_remote, :json)
    |> process_query(options.data)
    |> Map.fetch!(:body)
    |> Poison.decode!
    |> maybe_convert_na_to_nil(options.convert_na_to_nil)
  end

  defp maybe_convert_na_to_nil(data, false), do: data
  defp maybe_convert_na_to_nil(data, true), do: convert_na_to_nil(data)

  @doc """
  Return the package description
  """
  @spec description(String.t, Map) :: String.t
  def description(package, options \\ %{}) do
    options = Map.merge(%Options{}, options)

    response =
      "#{package_url(package, options.user, options.github_remote)}/info"
      |> get(request_options(nil))

    case response.status_code in [200, 201] do
      true  -> response.body
      false -> raise OpenCPU.OpenCPUError, message:
        "Error getting description, status code #{response.status_code}: #{response.body}"
    end
  end

  @spec prepare(String.t, String.t, Map) :: %OpenCPU.DelayedCalculation{}
  def prepare(package, function, options \\ %{}) do
    options = Map.merge(%Options{}, options)

    response =
      function_url(package, function, options.user, options.github_remote, nil)
      |> process_query(options.data)

    OpenCPU.DelayedCalculation.new(
      response.headers.hdrs |> Map.get("location"),
      response.body |> String.split("\n")
    )
  end

  defp process_query(url, data) do
    response = post(url, request_options(data))

    case response.status_code do
      code when code in [200, 201] ->
        response
      403 ->
        raise OpenCPU.AccessDenied, message: response.body
      code when code in 400..499 ->
        raise OpenCPU.BadRequest, message: response.body
      code when code in 500..599 ->
        raise OpenCPU.InternalServerError, message: response.body
      _ ->
        raise OpenCPU.OpenCPUError, message:
          "Invalid status code: #{response.status_code}, #{response.body}"
    end
  end

  @doc """
  Recursively replace all `"NA"` values with `nil`.
  """
  def convert_na_to_nil("NA"), do: nil
  def convert_na_to_nil(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, convert_na_to_nil(v)} end)
    |> Enum.into(%{})
  end
  def convert_na_to_nil(data) when is_list(data) do
    data
    |> Enum.map(fn v -> convert_na_to_nil(v) end)
  end
  def convert_na_to_nil(data), do: data

  defp request_options(data) do
    options = [
      verify: get_env(:verify_ssl, true),
      body: Poison.encode!(data),
      headers: ["Content-Type": "application/json"]
    ]

    if get_env(:username) && get_env(:password) do
      options
      |> Keyword.put(:basic_auth, {get_env(:username), get_env(:password)})
    else
      options
    end
  end

  def function_url(package, function, user \\ :system, github_remote \\ false, format \\ nil) do
    "#{package_url(package, user, github_remote)}/R/#{function}/#{format}"
  end

  defp package_url(package, :system, false) do
    "/library/#{package}"
  end

  defp package_url(package, user, false) do
    "/user/#{user}/library/#{package}"
  end

  defp package_url(package, user, true) do
    "/github/#{user}/#{package}"
  end

  defp get_env(key, default \\ nil) do
    Application.get_env(:opencpu, key, default)
  end
end
