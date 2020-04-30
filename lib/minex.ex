defmodule Minex do
  @moduledoc """
  A deployment helper for Elixir
  """

  use Agent

  defmacro __using__(_) do
    quote do
      import Minex.DSL
      Minex.start()
      Minex.load_base()
    end
  end


  @doc """
  Starts the minex agent
  """
  def start() do
    Agent.start_link(
      fn ->
        %{
          tasks: %{},
          variables: %{},
          mode: :local,
          commands: []
        }
      end,
      name: __MODULE__
    )
  end

  @doc """
  Stops the minex agent
  """
  def stop() do
    Agent.stop(__MODULE__, :normal)
  end

  @doc """
  Load the default tasks that can be used for deployment
  """
  def load_base() do
    Code.eval_file(Path.join([:code.priv_dir(:minex), "tasks", "base.exs"]))
  end

  @doc """
  Run a task by passing a list of strings
  """
  @spec run([String.t()]) :: any()
  def run([]) do
    run(["help"])
  end

  def run([name | rest]) do
    fun = Minex.Config.fetch_task!(String.to_atom(name))

    case rest do
      [] ->
        case Function.info(fun)[:arity] do
          0 -> fun.()
          1 -> fun.([])
        end

      rest ->
        fun.(rest)
    end
  end
end
