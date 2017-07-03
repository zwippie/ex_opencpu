defmodule OpenCPU.DelayedCalculationTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock
  alias OpenCPU.{Client, DelayedCalculation}

  setup_all do
    Application.put_env(:opencpu, :endpoint_url, "https://public.opencpu.org/ocpu")
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes")
    HTTPotion.start
    :ok
  end

  describe "new" do
    test "without resources" do
      delayed_calculation = DelayedCalculation.new "foo"
      assert delayed_calculation.available_resources == %{}
    end

    test "with resources" do
      resources = [
        "/foo/bar",
        "/foo/baz"
      ]
      parsed_resources = %{
        bar: URI.parse("https://opencpu.org:443/foo/bar"),
        baz: URI.parse("https://opencpu.org:443/foo/baz")
      }
      delayed_calculation = DelayedCalculation.new("https://opencpu.org/foo/", resources)
      assert delayed_calculation.available_resources == parsed_resources
    end
  end

  test "graphics" do
    # Use one test to save on cassettes (and lines of code :)
    use_cassette "animation_flip_coin_graphics" do
      delayed_calculation = Client.prepare("animation", "flip.coin")

      # it defines methods to access graphic functions
      assert DelayedCalculation.graphics(delayed_calculation) # not to raise error
      assert_raise OpenCPU.ResponseNotAvailableError, fn ->
        DelayedCalculation.stdout(delayed_calculation)
      end

      # it returns a SVG by default
      assert DelayedCalculation.graphics(delayed_calculation) =~ "svg xmlns"
      assert DelayedCalculation.graphics(delayed_calculation, 0, :svg)

      # it can return a PNG
      assert DelayedCalculation.graphics(delayed_calculation, 0, :png) =~ "PNG"
      assert DelayedCalculation.graphics(delayed_calculation, 0, :png)

      # it does not support formats except PNG and SVG
      assert_raise OpenCPU.UnsupportedFormatError, fn ->
        DelayedCalculation.graphics(delayed_calculation, 0, :foo)
      end
    end
  end

  test "standard getters" do
    use_cassette "animation_flip_coin_getters" do
      delayed_calculation = Client.prepare("animation", "flip.coin")

      # it returns raw R calculation result
      assert DelayedCalculation.value(delayed_calculation) =~ "$freq"

      # it returns cached stdout
      assert_raise OpenCPU.ResponseNotAvailableError, fn ->
        DelayedCalculation.stdout(delayed_calculation)
      end

      # it returns cached warnings
      assert_raise OpenCPU.ResponseNotAvailableError, fn ->
        DelayedCalculation.warnings(delayed_calculation)
      end

      # it returns cached info
      assert DelayedCalculation.info(delayed_calculation) =~ "R version"
    end
  end
end
