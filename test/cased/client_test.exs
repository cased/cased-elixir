defmodule Cased.ClientTest do
  use Cased.TestCase

  describe "parse_keys/1" do
    test "returns and empty map when given no values" do
      assert %{} == Cased.Client.parse_keys([])
    end

    test "returns a key for :default if :key option is given" do
      assert %{default: @example_key} == Cased.Client.parse_keys(key: @example_key)
    end

    test "returns keys as given with :keys option" do
      assert %{default: @example_key, other: @example_key2} ==
               Cased.Client.parse_keys(keys: [default: @example_key, other: @example_key2])
    end
  end

  describe "create/1" do
    test "returns a client with the default url if not provided" do
      assert {:ok, %{url: "https://api.cased.com"}} = Cased.Client.create(key: @example_key)
    end

    test "returns a client with a custom url if provided" do
      url = "https://api.example.com"
      assert {:ok, %{url: ^url}} = Cased.Client.create(url: url, key: @example_key)
    end

    test "returns a client with the default timeout if not provided" do
      assert {:ok, %{timeout: 15_000}} = Cased.Client.create(key: @example_key)
    end

    test "returns a client with a custom timeout if provided" do
      timeout = 10_000

      assert {:ok, %{timeout: ^timeout}} =
               Cased.Client.create(timeout: timeout, key: @example_key)
    end

    test "returns a client with a key for :default if :key option is given" do
      assert {:ok, %{keys: %{default: @example_key}}} = Cased.Client.create(key: @example_key)
    end

    test "returns a client with keys as given with :keys option" do
      assert {:ok, %{keys: %{default: @example_key, other: @example_key2}}} =
               Cased.Client.create(keys: [default: @example_key, other: @example_key2])
    end

    test "returns an error for bad key entries" do
      for key <- [@bad_key, @bad_key2, @bad_key3] do
        assert {:error, %Cased.ConfigurationError{details: [%{path: [:keys | _]}]}} =
                 Cased.Client.create(key: key)
      end
    end

    test "returns an error for a bad timeout" do
      for bad <- [-1, :forever] do
        assert {:error, %Cased.ConfigurationError{details: [%{path: [:timeout]}]}} =
                 Cased.Client.create(key: @example_key, timeout: bad)
      end
    end

    test "returns an error for a bad url" do
      # Note: last entry here is bad because it's a charlist vs string
      for bad <- ["not-a-url", 10_000, 'https://foo.bar'] do
        assert {:error, %Cased.ConfigurationError{details: [%{path: [:url]}]}} =
                 Cased.Client.create(key: @example_key, url: bad)
      end
    end
  end

  describe "create!/1" do
    test "raises an exception on bad options" do
      assert_raise Cased.ConfigurationError, "invalid client configuration", fn ->
        Cased.Client.create!(key: @bad_key)
      end
    end
  end
end
