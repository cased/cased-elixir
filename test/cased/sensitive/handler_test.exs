defmodule Cased.Sensitive.HandlerTest do
  use Cased.TestCase
  require Integer

  defmodule ScaryIntegerHandler do
    @behaviour Cased.Sensitive.Handler

    defstruct [:label, :checker]

    def new(label, checker) do
      %__MODULE__{label: label, checker: checker}
    end

    @doc """
    This is more complete than needed for testing, but serves as an example
    of a more complicated sensitive data detection scenario.
    """
    def ranges(handler, audit_event, {key, value}) when is_binary(value) do
      value =
        value
        |> Cased.Sensitive.String.new()

      ranges(handler, audit_event, {key, value})
    end

    def ranges(handler, _audit_event, {key, %Cased.Sensitive.String{} = value}) do
      value
      # [Naively] find all the integers
      |> Cased.Sensitive.String.matches(~r/\d+/)
      |> Enum.reduce([], fn {begin_offset, end_offset}, acc ->
        # Extract the integer and parse it
        {integer, ""} =
          value.data
          |> String.slice(begin_offset..(end_offset - 1))
          |> Integer.parse()

        # Use the custom checker that was used to configure the handler.
        case handler.checker.(integer) do
          true ->
            [
              %Cased.Sensitive.Range{
                label: handler.label,
                key: key,
                begin_offset: begin_offset,
                end_offset: end_offset
              }
              | acc
            ]

          false ->
            acc
        end
      end)
    end

    def ranges(_handler, _audit_event, _pair), do: []
  end

  describe "from_spec/1" do
    test "calls the handler's new/2 function" do
      spec = {ScaryIntegerHandler, :even, &Integer.is_even/1}

      handler =
        spec
        |> Cased.Sensitive.Handler.from_spec()

      assert %ScaryIntegerHandler{label: :even} = handler

      # Verify the checker function was stored
      assert handler.checker.(2)
      assert !handler.checker.(1)

      # Just verify our handler works
      result =
        ScaryIntegerHandler.ranges(
          handler,
          %{},
          {
            :body,
            # Courtesy of https://en.wikipedia.org/wiki/Squid
            "The majority of squid are no more than 60 cm (24 in) long, although the giant squid may reach 13 m (43 ft)."
          }
        )

      expected_result = [
        # 60
        %Cased.Sensitive.Range{begin_offset: 46, end_offset: 48, key: :body, label: :even},
        # 24
        %Cased.Sensitive.Range{begin_offset: 39, end_offset: 41, key: :body, label: :even}
      ]

      assert expected_result == result
    end
  end
end
