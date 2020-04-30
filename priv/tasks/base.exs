import Minex.DSL

set(:ssh_opts, "")
set(:scp_opts, "")

set(:local_command_options, [interact: true, echo_cmd: true])
set(:remote_command_options, [])

task(:local_exec, fn [command, options] ->
  Minex.Command.exec(command, options)
end)

task(:remote_exec, fn [command, options] ->
  command("ssh #{get(:ssh_opts)} #{get(:host)} -- #{Minex.Command.escape_single(command)}", options)
end)

task(:scp, fn [source, target] ->
  command("scp #{get(:scp_opts)} #{source} #{target}")
end)

task(:upload, fn [local, remote] ->
  run(:scp, [local, "#{get(:host)}:#{remote}"])
end)

task(:download, fn [remote, local] ->
  run(:scp, ["#{get(:host)}:#{remote}", local])
end)

task(:local_command, fn [command, options] ->
  options = Keyword.merge(get(:local_command_options), options)
  allow_fail = options[:allow_fail]

  case run(:local_exec, [command, options]) do
    {:ok, _} = ret -> ret
    other when allow_fail -> other
    other -> raise("Command failed with #{inspect other}\n  source: #{inspect command}")
  end
end)

task(:remote_command, fn args ->
  [command, options] = default_args(args, [nil, []])
  options = Keyword.merge(get(:remote_command_options), options)
  run(:remote_exec, ["( #{command} )", options])
end)

#
# Collect commands and execute them over ssh as a joined string
#
task(:remote, fn args ->
  [fun, opts] = default_args(args, [nil, []])
  if mode?(:remote) do
    fun.()
  else
    commands = collect(fn -> fun.() end, :remote)
    run(:remote_command, [commands |> Enum.join(" && "), opts])
  end
end)

#
# Queue or shell exec command based on if it's in a remote task or not
#
task(:command, fn [cmd, options] ->
  if mode?(:remote) || mode?(:collect) do
    collect_command(cmd)
  else
    run(:local_command, [cmd, options])
  end
end)

#
# Runs when running minex without a task
#
public_task(:help, fn ->
  task_names = tasks(:public) |> Keyword.keys() |> Enum.sort()

  IO.puts("""
  Available tasks:
    #{task_names |> Enum.join("\n  ")}
  """)
end)

#
# Generate script
#
set(:generate_script_template, """
set -e

case $1 in
<%= for {name, commands} <- tasks do %>
  <%= name %>)
    <%= commands |> Enum.join("\n    ") %>
    ;;
<% end %>
  *)
    echo "Unknown or missing command, available:
  <%= names |> Enum.join("\n  ") %>
"
    ;;
esac
""")

public_task(:generate_script, fn [target_path] ->
  tasks =
    tasks(:generate_script)
    |> Enum.map(fn {key, {fun, _}} ->
      commands = collect(fn -> fun.() end)
      {key, commands}
    end)

  names = Enum.map(tasks, fn {key, _} -> to_string(key) end) |> Enum.sort()
  script = get(:generate_script_template) |> EEx.eval_string([tasks: tasks, names: names], [])

  IO.puts("#{IO.ANSI.format([:green, "* creating"], true)} #{target_path}")
  File.write!(target_path, script)
  File.chmod(target_path, 0o755)
end)
