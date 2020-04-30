defmodule Minex.Command do
  alias __MODULE__

  @moduledoc """
  Execute shell commands
  """

  @doc """
  Execute a command and wait for it to finish

  ## Options

    * `:echo_cmd` - boolean indicating if the executed command should be printed
    * `:interact` - boolean to enable interact. This will read input lines from the terminal
      and sent them the executed command. It will also print all command output to stdout.
    * `:output_to_stdout` - boolean indicating to print all command output to stdout
    * `:on_receive` - anonymous function that receives a pid and a state map %{buffer: [...]}
      that allows you to handle command output and react to it.
    * `:pty` - boolean to enable pseudo terminal. Can be useful for executing ssh commands
    * `:env` - map or keyword list with the environment variables to be set (strings)
  """
  @spec exec(String.t(), keyword()) ::
          {:ok, String.t()}
          | {:error, String.t()}
          | {:error, {:exit_status, integer()}, String.t()}
  def exec(cmd, options \\ []) do
    {:ok, pid} = open(cmd, options)
    wait(pid, options)
  end

  @doc """
  Open the command, but do not wait for it to finish. Allows you to interact with it asynchronously.

  ## Options

    * `:echo_cmd` - boolean indicating if the executed command should be printed
    * `:output_to_stdout` - boolean indicating to print all command output to stdout
    * `:pty` - boolean to enable pseudo terminal. Can be useful for executing ssh commands
    * `:env` - map or keyword list with the environment variables to be set (strings)
  """
  @spec open(String.t(), keyword()) :: {:ok, pid()}
  def open(cmd, options \\ []) do
    maybe_echo_cmd(cmd, options[:echo_cmd])
    Command.Erlexec.start(cmd, options)
  end

  @doc """
  Send input to a running command
  """
  @spec send_input(pid(), String.t()) :: :ok
  def send_input(pid, input) do
    GenServer.cast(pid, {:send_input, input})
  end

  @doc """
  Wait for a command to finish and receive it's output

  ## Options

    * `:interact` - boolean to enable interact. This will read input lines from the terminal
      and sent them the executed command. It will also print all command output to stdout.
    * `:on_receive` - anonymous function that receives a pid and a state map %{buffer: [...]}
      that allows you to handle command output and react to it.
  """
  @spec wait(pid(), keyword()) ::
          {:ok, String.t()}
          | {:error, String.t()}
          | {:error, {:exit_status, integer()}, String.t()}
  def wait(pid, options \\ [], state \\ %{buffer: []}) do
    if options[:interact] do
      pid = self()

      spawn(fn ->
        line = IO.binread(:stdio, :line)
        send(pid, {:readline, line})
      end)
    end

    receive do
      {:readline, input} ->
        send_input(pid, input)
        wait(pid, options, state)

      {_pid, {:exit_status, status}} when status > 0 ->
        {:error, {:exit_status, status}, collect_output(state)}

      {_pid, {:exit_status, 0}} ->
        {:ok, collect_output(state)}

      {pid, {:data, data}} ->
        state = %{state | buffer: [data | state.buffer]}

        if options[:on_receive] do
          case options[:on_receive].(pid, state) do
            {:cont, state} ->
              wait(pid, options, state)

            :detach ->
              {:ok, collect_output(state)}

            {:error, state} ->
              Process.exit(pid, :normal)
              {:error, collect_output(state)}

            {:done, state} ->
              Process.exit(pid, :normal)
              {:ok, collect_output(state)}
          end
        else
          wait(pid, options, state)
        end

      _msg ->
        wait(pid, options, state)
    end
  end

  @doc """
  Escape double quotes in a command and wrap it in double quotes
  """
  @spec escape(String.t()) :: String.t()
  def escape(value), do: escape(value, "")
  defp escape("", res), do: "\"#{res}\""
  defp escape("\"" <> value, res), do: escape(value, res <> "\\\"")
  defp escape("\\" <> value, res), do: escape(value, res <> "\\\\")
  defp escape(<<char::utf8, rest::binary>>, res), do: escape(rest, res <> <<char>>)

  @doc """
  Escape single quotes in a command and wrap it in `$'...'`
  """
  @spec escape_single(String.t()) :: String.t()
  def escape_single(value), do: escape_single(value, "")
  defp escape_single("", res), do: "$'#{res}'"
  defp escape_single("'" <> value, res), do: escape_single(value, res <> "\\'")
  defp escape_single("\\" <> value, res), do: escape_single(value, res <> "\\\\")
  defp escape_single(<<char::utf8, rest::binary>>, res), do: escape_single(rest, res <> <<char>>)

  @doc """
  Collect the output of the command state map and joins it into a single string
  """
  @spec collect_output(%{buffer: [String.t()]}) :: String.t()
  def collect_output(%{buffer: buffer}), do: buffer |> Enum.reverse() |> Enum.join("")

  defp maybe_echo_cmd(cmd, true),
    do: IO.puts("#{IO.ANSI.format([:green, "* exec"], true)} #{cmd}")

  defp maybe_echo_cmd(_, _), do: :ok
end
