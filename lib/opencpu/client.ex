defmodule OpenCPU.Client do
  @moduledoc """
  OpenCPU client to interact with a OpenCPU server, see https://www.opencpu.org/.
  """

  defmodule Options do
    defstruct [
      user: :system,
      data: %{},
      format: :json, # useless option now?
      github_remote: false,
      convert_na_to_nil: false
    ]
  end

  @doc """
  Execute a request on an OpenCPU server and parse the JSON result.
  """
  @spec execute(String.t, String.t, Map) :: Map
  def execute(package, function, options \\ %{}) do
    options = Map.merge(%Options{}, options)

    function_url(package, function, options.user, options.github_remote, :json)
    |> process_url
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
      |> process_url
      |> HTTPoison.get(headers(), request_options())

    case response do
      {:ok, %HTTPoison.Response{status_code: code} = response} when code in [200, 201] ->
        response.body
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        raise OpenCPU.OpenCPUError, message: "Error getting description: #{code}, #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise OpenCPU.OpenCPUError, message: "Error: #{reason}"
    end
  end

  @doc """
  Execute a function and return a struct that can be used to get more
  resources included with the result of the command.

    result = OpenCPU.Client.prepare("my", "picture")
    png = OpenCPU.DelayedCalculation.graphics(result, 0, :png)
  """
  @spec prepare(String.t, String.t, Map) :: %OpenCPU.DelayedCalculation{}
  def prepare(package, function, options \\ %{}) do
    options = Map.merge(%Options{}, options)

    response =
      function_url(package, function, options.user, options.github_remote, nil)
      |> process_url
      |> process_query(options.data)

    OpenCPU.DelayedCalculation.new(
      response.headers |> Enum.into(%{}) |> Map.get("Location"),
      response.body |> String.split("\n")
    )
  end

  defp process_query(url, data) do
    data = Poison.encode!(data)

    case HTTPoison.post(url, data, headers(), request_options()) do
      {:ok, %HTTPoison.Response{status_code: code} = response} when code in [200, 201] ->
        response
      {:ok, %HTTPoison.Response{status_code: 403, body: body}} ->
        raise OpenCPU.AccessDenied, message: body
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 400..499 ->
        raise OpenCPU.BadRequest, message: body
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 500..599 ->
        raise OpenCPU.BadRequest, message: body
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        raise OpenCPU.OpenCPUError, message: "Invalid status code: #{code}, #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise OpenCPU.OpenCPUError, message: "Error: #{reason}"
    end
  end

  def process_url(url) do
    case endpoint_url = get_env(:endpoint_url) do
      nil -> raise OpenCPU.OpenCPUError, message: "OpenCPU endpoint is not configured"
      _   -> endpoint_url <> url
    end
  end

  def headers do
    [{"Content-Type", "application/json"}]
  end

  def request_options do
    case {get_env(:username), get_env(:password)} do
      {nil, _}             -> []
      {_, nil}             -> []
      {username, password} -> [hackney: [basic_auth: {username, password}]]
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
