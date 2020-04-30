defmodule Minex.DSL do
  alias Minex.Config

  @doc """
  Set a (global) variable by keyword list. Returns the previous values or nil if unset

  ```
  set(a: value_a, b: value_b)
  ```
  """
  @spec set(keyword()) :: keyword()
  def set(keyword_list) when is_list(keyword_list) do
    Config.set(keyword_list)
  end

  @doc """
  Set a (global) variable. Returns the previous value or nil if unset

  ```
  set(:key, value)
  ```
  """
  @spec set(atom(), any() | (() -> any())) :: any()
  def set(key, value_or_fun) do
    Config.set(key, value_or_fun)
  end

  @doc """
  Read a (global) variable.

  ```
  val = get(:key)
  val = get(:key, "default")
  ```
  """
  @spec get(atom(), any()) :: any()
  def get(key, default \\ nil) do
    case Config.get(key) do
      fun when is_function(fun) -> fun.()
      nil -> default
      other -> other
    end
  end

  @doc """
  Define a public task. Public tasks can be called from the command line (or by `Minex.run(["task_name"])`)

  ```
  public_task(:task_name, fn ->
    command("ls")
  end)
  ```
  """
  @spec public_task(atom(), keyword(), fun()) :: :ok
  def public_task(name, options \\ [], fun) do
    task(name, options ++ [public: true], fun)
  end

  @doc """
  Tasks defined with `generate_script_task` can be exported to a bash script by the `generate_script` task.

  This is useful for when you need a full terminal support, instead of it emulated through elixir. For example
  to start a remote iex session.

  ```
  generate_script_task(:task_name, fn ->
    run(:remote, fn ->
      command("cd \#{get(:deploy_to)} && ./bin/\#{get(:name)} remote")
    end)
  end)
  ```

  ```
  mix minex generate_script target_path
  ```
  """
  @spec generate_script_task(atom(), keyword(), fun()) :: :ok
  def generate_script_task(name, options \\ [], fun) do
    task(name, options ++ [generate_script: true], fun)
  end

  @doc """
  Define an internal task. These tasks can only be run by calling `run(:task_name)`.

  ```
  task(:task_name, fn ->
    command("ls")
  end)
  ```
  """
  @spec task(atom(), keyword(), fun()) :: :ok
  def task(name, options \\ [], fun) do
    Config.put_task(name, fun, options)
  end

  @doc """
  Run a task by name. Returns whatever is returned in the task itself.

  ```
  run(:my_task)
  run(:my_task, single_arg)
  run(:my_task, [a, b, c])
  ```
  """
  def run(name) do
    fun = Config.fetch_task!(name)

    case Function.info(fun)[:arity] do
      0 -> fun.()
      1 -> fun.([])
    end
  end

  def run(name, arg) when not is_list(arg) do
    fun = Config.fetch_task!(name)
    fun.([arg])
  end

  def run(name, args) do
    fun = Config.fetch_task!(name)
    fun.(args)
  end

  @doc """
  Shortcut for `run(:command, [cmd, options])`

  ```
  command("my_cmd")
  command("my_cmd", echo_cmd: false)
  ```
  """
  def command(cmd, options \\ []) do
    run(:command, [cmd, options])
  end

  @doc """
  Collect commands without executing them. Sets a mode that you can use to check
  in tasks if needed.

  ```
  task(:dry_run, fn [fun] ->
    collect(fun)
    |> Enum.join("\\n")
    |> IO.puts()
  end)

  task(:example_task, fn ->
    command("a")
    command("b")
    command("c")
  end)

  run(:dry_run, fn ->
    run(:example_task)
  end)
  ```
  """
  def collect(fun, mode \\ :collect) do
    prev_commands = get(:__commands)
    prev_mode = get(:__mode)
    set(:__commands, [])
    set(:__mode, mode)
    fun.()
    commands = get(:__commands)
    set(:__mode, prev_mode)
    set(:__commands, prev_commands)
    Enum.reverse(commands)
  end

  @doc """
  Check if mode is set
  """
  def mode?(mode) do
    get(:__mode) == mode
  end

  @doc """
  Add a single command to the list of collected commands. Stored in `:__commands`.
  """
  def collect_command(command) do
    set(:__commands, [command | get(:__commands)])
  end

  @doc """
  Get a list of all defined tasks. Returns a map with the task names as key (atoms) and the
  values as {fun, options}
  """
  @spec tasks() :: %{optional(atom()) => {fun(), keyword()}}
  def tasks() do
    Config.tasks()
  end

  @doc """
  Get a list of all defined tasks with a certain option set. Public tasks have the `:public`
  option set and generate script tasks have the `:generate_script` option set.
  """
  @spec tasks(atom()) :: %{optional(atom()) => {fun(), keyword()}}
  def tasks(option) do
    Config.tasks(option)
  end

  @doc """
  Fetch a task by name. Raises if the task is not defined.
  """
  @spec fetch_task!(atom()) :: fun()
  def fetch_task!(name) do
    case Agent.get(Minex, fn state -> Map.get(state.tasks, name) end) do
      {fun, _} -> fun
      nil -> raise("task '#{name}' is not defined")
    end
  end

  @doc """
  Helper to add default arguments from a list of arguments.

  ```
  args = []
  default_args(args, [1, 2]) # => [1, 2]

  args = [:a]
  default_args(args, [1, 2]) # => [:a, 2]
  ```
  """
  @spec default_args(nil | list(), list()) :: list()
  def default_args(nil, list), do: list
  def default_args([], list), do: list
  def default_args([arg | args], [_default | list]), do: [arg] ++ default_args(args, list)
  def default_args(args, []), do: args
end
