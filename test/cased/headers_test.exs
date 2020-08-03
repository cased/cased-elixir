defmodule Cased.HeadersTest do
  use Cased.TestCase, async: true

  describe "parse_pagination_info/1" do
    test "returns nil for nil" do
      assert nil == Cased.Headers.parse_pagination_info(nil)
    end

    test "returns pagination info " do
      link =
        ~s(<http://localhost:49998/events?page=1&per_page=25>; rel="first", <http://localhost:49998/events?page=3&per_page=25>; rel="last", <http://localhost:49998/events?page=2&per_page=25>; rel="self")

      assert %{first: 1, last: 3, self: 2} == Cased.Headers.parse_pagination_info(link)
    end
  end
end
