defmodule MinexTest do
  use ExUnit.Case
  import Minex.DSL

  setup do
    Minex.start()
    :ok
  end

  test "get/set" do
    set(:bla, 1)
    assert get(:bla) == 1
  end

  test "set returns previous value" do
    assert set(:bla, 1) == nil
    assert set(:bla, 2) == 1
  end

  test "set keyword list" do
    set(a: 1, b: 2)
    assert get(:a) == 1
    assert get(:b) == 2
  end

  test "set keyword list returns previous values" do
    set(a: 1, b: 2, c: 3)
    previous_values = set(b: 4, c: 5, d: 6)
    assert previous_values == [b: 2, c: 3, d: nil]
  end

  test "can set to temporarily set values" do
    set(a: 1, b: 2, c: 3)

    previous_values = set(b: 4, c: 5, d: 6)
    assert get(:a) == 1
    assert get(:b) == 4
    assert get(:c) == 5
    assert get(:d) == 6

    set(previous_values)
    assert get(:a) == 1
    assert get(:b) == 2
    assert get(:c) == 3
    assert get(:d) == nil
  end

  test "undefined get returns nil" do
    assert get(:bla) == nil
  end

  test "define and run a task" do
    task(:test, fn -> :ok end)
    assert Minex.run(["test"]) == :ok
  end

  test "task with args" do
    task(:sub, fn [name] -> {:ok, name} end)
    public_task(:test, fn -> run(:sub, ["Bob"]) end)
    assert Minex.run(["test"]) == {:ok, "Bob"}
  end

  test "task with default args" do
    task(:sub, fn args ->
      [name, options] = default_args(args, ["", []])
      {:ok, name, options}
    end)

    public_task(:test1, fn -> run(:sub) end)
    public_task(:test2, fn -> run(:sub, ["Bob"]) end)
    public_task(:test3, fn -> run(:sub, ["Bob", [opt: true]]) end)

    assert Minex.run(["test1"]) == {:ok, "", []}
    assert Minex.run(["test2"]) == {:ok, "Bob", []}
    assert Minex.run(["test3"]) == {:ok, "Bob", [opt: true]}
  end

  test "mismatch args" do
    task(:sub, fn [name] -> {:ok, name} end)
    public_task(:test, fn -> run(:sub) end)
    assert_raise(FunctionClauseError, fn -> Minex.run(["test"]) end)
  end

  test "warn on override" do
    import ExUnit.CaptureIO
    task(:test, fn -> 1 end)

    assert capture_io(:stderr, fn ->
             task(:test, fn -> 2 end)
           end) =~ "is being redefined"
  end

  test "dont warn if override: true" do
    import ExUnit.CaptureIO
    task(:test, fn -> 1 end)

    refute capture_io(:stderr, fn ->
             task(:test, [override: true], fn -> 2 end)
           end) =~ "is being redefined"
  end

  test "run an undefined task" do
    assert_raise(RuntimeError, ~r/is not defined/, fn -> Minex.run(["test"]) end)
  end

  test "run an undefined subtask" do
    task(:test, fn -> run(:bla) end)
    assert_raise(RuntimeError, ~r/is not defined/, fn -> Minex.run(["test"]) end)
  end
end
