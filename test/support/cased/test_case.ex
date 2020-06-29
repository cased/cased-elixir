defmodule Cased.TestCase do
  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: true
      import Cased.BypassTagHelper

      @example_key "policy_test_FOO"
      @example_key2 "policy_test_BAR"

      @bad_key "policy_bad_FOO"
      @bad_key2 "publish_live_FOO"
      @bad_key3 "text "

      setup context do
        case context[:bypass] do
          nil ->
            {:ok, client: Cased.Client.create!(key: @example_key)}

          settings ->
            bypass = Bypass.open()

            configure_bypass(bypass, settings)

            {:ok,
             bypass: bypass,
             client:
               Cased.Client.create!(key: @example_key, url: "http://localhost:#{bypass.port}")}
        end
      end
    end
  end
end
