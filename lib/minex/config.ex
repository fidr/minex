defmodule Minex.Config do
  def set(keyword_list) when is_list(keyword_list) do
    Agent.get_and_update(Minex, fn state ->
      previous = Enum.map(keyword_list, fn {k, _v} -> {k, Map.get(state.variables, k)} end)
      {previous, %{state | variables: Map.merge(state.variables, Map.new(keyword_list))}}
    end)
  end

  def set(key, value_or_fun) do
    Agent.get_and_update(Minex, fn state ->
      {Map.get(state.variables, key),
       %{state | variables: Map.put(state.variables, key, value_or_fun)}}
    end)
  end

  def get(key) do
    Agent.get(Minex, fn state -> Map.get(state.variables, key) end)
  end

  def put_task(name, fun, options) do
    Agent.update(Minex, fn state ->
      if !options[:override] && Map.get(state.tasks, name) do
        IO.warn("Task '#{name}' is being redefined")
      end

      %{state | tasks: Map.put(state.tasks, name, {fun, options})}
    end)
  end

  def tasks() do
    Agent.get(Minex, fn state -> state.tasks end)
  end

  def tasks(option) do
    Agent.get(Minex, fn state -> state.tasks end)
    |> Enum.filter(fn {_key, {_fun, options}} -> options[option] end)
    |> Map.new()
  end

  def fetch_task!(name) do
    case Agent.get(Minex, fn state -> Map.get(state.tasks, name) end) do
      {fun, _} -> fun
      nil -> raise("Task '#{name}' is not defined")
    end
  end
end
