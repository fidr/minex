defmodule Minex.Command.Erlexec do
  use GenServer

  def start(cmd, options) do
    GenServer.start_link(__MODULE__, {cmd, self(), options})
  end

  def send_input(pid, data) do
    GenServer.cast(pid, {:send_input, data})
  end

  def init({cmd, from, options}) do
    opts = [:stdin, :stdout, :stderr, :monitor]
    opts = if options[:pty], do: [:pty | opts], else: opts
    opts = if options[:env], do: [{:env, convert_env(options[:env])} | opts], else: opts
    {:ok, _pid, id} = :exec.run(String.to_charlist(cmd), opts)
    {:ok, %{id: id, from: from, options: options}}
  end

  def handle_cast({:send_input, input}, state) do
    :exec.send(state.id, input)
    {:noreply, state}
  end

  def handle_info({:DOWN, _id, :process, _pid, {:exit_status, status}}, %{from: from} = state) do
    send(from, {self(), {:exit_status, status}})
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _id, :process, _pid, :normal}, %{from: from} = state) do
    send(from, {self(), {:exit_status, 0}})
    {:stop, :normal, state}
  end

  def handle_info({:stdout, _id, data}, %{options: options, from: from} = state) do
    if options[:output_to_stdout] || options[:interact], do: IO.write(data)
    send(from, {self(), {:data, data}})
    {:noreply, state}
  end

  def handle_info({:stderr, _id, data}, %{options: options, from: from} = state) do
    if options[:output_to_stdout] || options[:interact], do: IO.write(data)
    send(from, {self(), {:data, data}})
    {:noreply, state}
  end

  def handle_info(msg, state) do
    send(state.from, {self(), msg})
    {:noreply, state}
  end

  def convert_env(env) do
    Enum.map(env, fn
      {k, v} when is_atom(k) -> {Atom.to_charlist(k), String.to_charlist(v)}
      {k, v} -> {String.to_charlist(k), String.to_charlist(v)}
    end)
  end
end
