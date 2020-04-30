defmodule CommandTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "run a command" do
    {:ok, "test\n"} = Minex.Command.exec(~s[echo "test"])
  end

  test "echo cmd" do
    output =
      capture_io(fn ->
        Minex.Command.exec(~s[echo "test"], echo_cmd: true)
      end)

    assert output =~ ~s[echo "test"]
  end

  test "output to stdout" do
    output = capture_io(fn -> Minex.Command.exec(~s[echo "test"], output_to_stdout: true) end)
    assert output == "test\n"
  end

  test "send input" do
    output =
      capture_io(fn ->
        {:ok, pid} = Minex.Command.open(~s[read var; echo "Hello $var"], output_to_stdout: true)

        Minex.Command.send_input(pid, "Bob\n")
        Minex.Command.wait(pid)
      end)

    assert output == "Hello Bob\n"
  end

  test "get output" do
    assert {:ok, "test\n"} = Minex.Command.exec(~s[echo "test"])
  end

  test "get stderr" do
    assert {:ok, "err\n"} = Minex.Command.exec(~s[echo "err" 1>&2])
  end

  test "with env" do
    assert {:ok, "bar\n"} = Minex.Command.exec(~s[echo $FOO], env: %{"FOO" => "bar"})
  end

  test "with keyword env" do
    assert {:ok, "123\n"} = Minex.Command.exec(~s[echo $bla], env: [bla: "123"])
  end

  test "with inline env" do
    assert {:ok, "bar hey\n"} = Minex.Command.exec(~s[FOO=bar;BAR=hey; echo "$FOO $BAR"])
  end

  test "scripted interactive" do
    {:ok, pid} =
      Minex.Command.open(
        [
          ~s[echo "Starting"],
          ~s[printf "First name: "],
          ~s[read first],
          ~s[printf "Last name: "],
          ~s[read last],
          ~s[echo "Hello $first $last"]
        ]
        |> Enum.join(" ; ")
      )

    on_receive = fn pid, %{buffer: [data | _]} = state ->
      cond do
        data =~ "First name:" ->
          Minex.Command.send_input(pid, "James\n")
          {:cont, %{state | buffer: []}}

        data =~ "Last name:" ->
          Minex.Command.send_input(pid, "Bond\n")
          {:cont, %{state | buffer: []}}

        true ->
          {:cont, state}
      end
    end

    assert {:ok, "Hello James Bond\n"} = Minex.Command.wait(pid, on_receive: on_receive)
  end
end
