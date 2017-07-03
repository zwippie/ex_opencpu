defmodule OpenCPU.DelayedCalculation do
  alias OpenCPU.DelayedCalculation

  defstruct location: nil, available_resources: %{}

  def new(location, resources \\ []) do
    %DelayedCalculation{
      location: location,
      available_resources: parse_resources(location, resources)
    }
  end

  def graphics(%DelayedCalculation{} = delayed_calculation, which \\ 0, type \\ :svg) do
    if not Map.has_key?(delayed_calculation.available_resources, :graphics), do:
      raise OpenCPU.ResponseNotAvailableError

    if not type in [:png, :svg], do:
      raise OpenCPU.UnsupportedFormatError

    resource =
      delayed_calculation.available_resources.graphics
      |> Enum.at(which)
      |> to_string

    process_resource(resource <> "/#{type}")
  end

  def value(%DelayedCalculation{} = delayed_calculation) do
    fetch_resource(delayed_calculation, :value)
  end

  def stdout(%DelayedCalculation{} = delayed_calculation) do
    fetch_resource(delayed_calculation, :stdout)
  end

  def warnings(%DelayedCalculation{} = delayed_calculation) do
    fetch_resource(delayed_calculation, :warnings)
  end

  def source(%DelayedCalculation{} = delayed_calculation) do
    fetch_resource(delayed_calculation, :source)
  end

  def console(%DelayedCalculation{} = delayed_calculation) do
    fetch_resource(delayed_calculation, :console)
  end

  def info(%DelayedCalculation{} = delayed_calculation) do
    fetch_resource(delayed_calculation, :info)
  end

  defp fetch_resource(%DelayedCalculation{} = delayed_calculation, key) do
    case Map.fetch(delayed_calculation.available_resources, key) do
      {:ok, resource} -> process_resource(resource)
      :error -> raise OpenCPU.ResponseNotAvailableError
    end
  end

  defp process_resource(resource) do
    case response = HTTPotion.get(resource, [follow_redirects: true]) do
      %HTTPotion.Response{} ->
        String.trim(response.body)
      %HTTPotion.ErrorResponse{message: message} ->
        raise OpenCPU.BadRequest, message: "Error loading resource '#{resource}': #{message}"
    end
  end

  defp parse_resources(location, resources, acc \\ %{})

  defp parse_resources(_, [], acc), do: acc

  defp parse_resources(location, [resource | resources], acc) do
    uri = URI.merge(domain(location), resource)

    acc = case key = key(uri, location) do
      :graphics ->
        uris = get_in(acc, [key]) |> List.wrap
        put_in(acc, [key], [uri | uris])
      key ->
        put_in(acc, [key], uri)
    end

    parse_resources(location, resources, acc)
  end

  defp domain(location) do
    uri = URI.parse(location)
    "#{uri.scheme}://#{uri.host}:#{uri.port}"
  end

  defp key(uri, location) do
    key = URI.to_string(uri) |> String.replace(location, "")
    cond do
      key == "R/.val"         -> :value
      key =~ ~r/graphics\/\d/ -> :graphics
      is_binary(key)          -> String.to_atom(key)
      true                    -> key
    end
  end
end
