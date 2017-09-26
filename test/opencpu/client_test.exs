defmodule OpenCPU.ClientTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias OpenCPU.Client

  setup_all do
    HTTPoison.start
    :ok
  end

  setup do
    Application.put_env(:opencpu, :endpoint_url, "https://public.opencpu.org/ocpu")
    :ok
  end

  describe "execute" do
    test "it raises an exception if the endpoint_url is not configured" do
      use_cassette "no_endpoint_configured" do
        assert_raise OpenCPU.OpenCPUError, "OpenCPU endpoint is not configured", fn ->
          Application.put_env(:opencpu, :endpoint_url, nil)
          Client.execute(:animation, "flip.coin")
        end
      end
    end

    test "it can return JSON results" do
      use_cassette "flip_coin" do
        response = Client.execute(:animation, "flip.coin")
        assert Map.keys(response) == ["freq", "nmax"]
      end
    end

    test "it raises an exception on bad requests" do
      use_cassette "bad_request" do
        assert_raise OpenCPU.BadRequest, "unused argument (some = c(\"data\"))\n\nIn call:\nidentity(some = c(\"data\"))\n", fn ->
          Client.execute(:base, :identity, %{data: %{some: "data"}})
        end
      end
    end

    test "it accepts R-function parameters as data" do
      use_cassette "digest_hmac" do
        response = Client.execute(:digest, :hmac, %{data: %{key: "baz", object: "qux", algo: "sha256"}})
        assert response == ["e48bbe6502785b0388ddb386a3318a52a8cc41bfe3ac696223122266e32c919a"]
      end
    end

    test "it converts NA to nil if option is set" do
      use_cassette "response_with_na_values" do
        response = Client.execute(:base, :identity, %{data: %{x: %{x: "NA", y: "not_na"}}, convert_na_to_nil: true})
        assert response == %{"x"=>[nil], "y"=>["not_na"]}
      end
    end
  end

  describe "description" do
    test "it returns the content of the package DESCRIPTION file" do
      use_cassette "description" do
        response = Client.description("ade4")
        assert String.starts_with?(response, "\n\t\tInformation on package 'ade4'\n\n")
      end
    end
  end

  describe "prepare" do
    test "it returns a DelayedCalculation" do
      use_cassette "prepare" do
        response = Client.prepare(:digest, :hmac, %{data: %{key: "baz", object: "qux", algo: "sha256"}})
        assert %OpenCPU.DelayedCalculation{} = response
      end
    end
  end

  describe "convert_na_to_nil" do
    test "it converts 'NA' values in hashes in arrays" do
      assert [4, %{foo: nil}] == Client.convert_na_to_nil([4, %{foo: "NA"}])
    end

    test "it converts 'NA' values in arrays in hashes" do
      assert %{foo: [1, nil]} == Client.convert_na_to_nil(%{foo: [1, "NA"]})
    end

    test "it leaves other values alone" do
      assert %{foo: [1, "NOTNA"]} == Client.convert_na_to_nil(%{foo: [1, "NOTNA"]})
    end
  end

  describe "github_remote" do
    @tag skip: "Figure out what package to use"
    test "it can access github packages" do
      use_cassette "github_package" do
        Application.put_env(:opencpu, :endpoint_url, "https://cloud.opencpu.org/ocpu")
        response = Client.execute("ropensciDemos", "www", %{user: "ropensci", github_remote: true, data: %{}})
        assert response =~ "Welcome to rOpenSci Demos"
      end
    end

    test "what happens when package is not available on GitHub" do
      use_cassette "github_package_not_found" do
        assert_raise OpenCPU.BadRequest, fn ->
          Client.execute(:foo, :bar, %{user: "baz", github_remote: true})
        end
      end
    end
  end

  describe "function_url and package_url" do
    test "system libraries" do
      assert Client.function_url("package", "function")
          == "/library/package/R/function/"
    end

    test "json response" do
      assert Client.function_url("package", "function", :system, false, :json)
          == "/library/package/R/function/json"
    end

    test "user libraries" do
      assert Client.function_url("package", "function", "username")
          == "/user/username/library/package/R/function/"
    end

    test "github libraries" do
      assert Client.function_url("package", "function", "username", true)
          == "/github/username/package/R/function/"
    end
  end
end
