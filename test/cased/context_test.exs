defmodule Cased.ContextTest do
  use Cased.TestCase
  doctest Cased.Context

  describe "put/2" do
    test "puts a value into the context" do
      assert is_nil(Cased.Context.get(:foo))

      Cased.Context.put(:foo, 1)
      assert 1 == Cased.Context.get(:foo)

      assert 1 == Cased.Context.stack_size()
    end
  end

  describe "put/3" do
    test "puts a value into the context, temporarily" do
      assert !Cased.Context.has_key?(:foo)
      assert 0 == Cased.Context.stack_size()

      Cased.Context.put(:foo, 1, fn ->
        assert 1 == Cased.Context.get(:foo)
      end)

      assert !Cased.Context.has_key?(:foo)
      assert 0 == Cased.Context.stack_size()
    end

    test "puts a value into the context, temporarily, even when nested" do
      assert !Cased.Context.has_key?(:foo)
      assert 0 == Cased.Context.stack_size()

      Cased.Context.put(:foo, 1, fn ->
        assert 1 == Cased.Context.get(:foo)

        Cased.Context.put(:bar, 2, fn ->
          assert %{foo: 1, bar: 2} == Cased.Context.to_map()
        end)

        assert !Cased.Context.has_key?(:bar)
      end)

      assert !Cased.Context.has_key?(:foo)
      assert 0 == Cased.Context.stack_size()
    end
  end

  describe "merge/1" do
    test "merges a map of values into the context" do
      Cased.Context.put(:foo, 1)
      assert 1 == Cased.Context.stack_size()

      Cased.Context.merge(%{foo: 2})
      assert 2 == Cased.Context.stack_size()

      Cased.Context.merge(%{bar: 1})
      assert 3 == Cased.Context.stack_size()

      assert %{foo: 2, bar: 1} == Cased.Context.to_map()
    end
  end

  describe "merge/2" do
    test "merges a map of values into the context, temporarily" do
      Cased.Context.put(:foo, 1)
      assert 1 == Cased.Context.stack_size()

      Cased.Context.merge(%{foo: 2, bar: 1}, fn ->
        assert 2 == Cased.Context.stack_size()
        assert %{foo: 2, bar: 1} == Cased.Context.to_map()
      end)

      assert 1 == Cased.Context.stack_size()
      assert %{foo: 1} == Cased.Context.to_map()
    end

    test "merges a map of values into the context, temporarily, even when nested" do
      Cased.Context.put(:foo, 1)
      assert 1 == Cased.Context.stack_size()

      Cased.Context.merge(%{foo: 2, bar: 1}, fn ->
        assert 2 == Cased.Context.stack_size()
        assert %{foo: 2, bar: 1} == Cased.Context.to_map()

        Cased.Context.merge(%{baz: 3}, fn ->
          assert 3 == Cased.Context.stack_size()
          assert %{foo: 2, bar: 1, baz: 3} == Cased.Context.to_map()
        end)
      end)

      assert 1 == Cased.Context.stack_size()
      assert %{foo: 1} == Cased.Context.to_map()
    end
  end

  describe "get/1" do
    test "gets a value from the context" do
      assert is_nil(Cased.Context.get(:foo))

      Cased.Context.put(:foo, 1)
      assert 1 == Cased.Context.get(:foo)
    end

    test "gets the latest value from the context" do
      assert is_nil(Cased.Context.get(:foo))

      Cased.Context.put(:foo, 1)
      Cased.Context.put(:foo, 2)
      assert 2 == Cased.Context.get(:foo)
    end
  end

  describe "get/2" do
    test "gets a value from the context, with a default" do
      assert :default == Cased.Context.get(:foo, :default)
    end
  end

  describe "reset/0" do
    test "when there was no context set" do
      assert nil == Cased.Context.reset()
      assert !Cased.Context.has_stack?()
    end

    test "when there was a context set" do
      Cased.Context.put(:key, "value")
      assert :ok == Cased.Context.reset()
      assert !Cased.Context.has_stack?()
    end

    test "when there was a context set, but is empty" do
      Cased.Context.put(:key, "value", fn -> :ok end)
      assert nil == Cased.Context.reset()
      assert !Cased.Context.has_stack?()
    end
  end
end
