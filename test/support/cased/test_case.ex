defmodule Cased.TestCase do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: true
      import Cased.BypassTagHelper

      @default_key "policy_test_FOO"
      @organizations_key "policy_test_BAR"

      @environment_key "environment_live_FOO"
      @environment_key2 "environment_live_BAR"
      @bad_environment_key "environment_bad_FOO"

      @bad_key "policy_bad_FOO"
      @bad_key2 "publish_live_FOO"
      @bad_key3 "text "

      setup context do
        case context[:bypass] do
          nil ->
            {:ok,
             client:
               Cased.Client.create!(
                 keys: [default: @default_key, organizations: @organizations_key],
                 environment_key: @environment_key
               )}

          settings ->
            bypass = Bypass.open()

            configure_bypass(bypass, settings)

            {:ok,
             bypass: bypass,
             client:
               Cased.Client.create!(
                 keys: [default: @default_key, organizations: @organizations_key],
                 environment_key: @environment_key,
                 url: "http://localhost:#{bypass.port}"
               )}
        end
      end
    end
  end
end
