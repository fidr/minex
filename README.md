# Minex

A deployment helper for Elixir.

Minex has no strong opinion on how you should do your deployments. It has no deployment strategies, but allows you to define them youself with a simple syntax. It does provide helpers to easily run commands. Both locally and over SSH (in a single session where possible).

Local commands are run with an interactive shell by default (using [Erlexec](https://github.com/saleyn/erlexec)). Remote commands are run as `ssh` commands.

## Installation

Add to your `mix.exs` and run `mix deps.get`:

```elixir
def deps do
  [
    {:minex, "~> 0.1.0", only: :dev}
  ]
end
```

Get started by running:

```
mix minex.init
```

This will create the following files:

- `config/deploy.exs`
- `config/deploy/tasks.exs`

## Get Started

The initial `deploy.exs` contains a basic sample of how a deployment can work. You define tasks that can execute commands locally or on a remote server.

Example deploy file:

```elixir
use Minex

set(:name, "my_app")
set(:deploy_to, "/apps/#{get(:name)}")
set(:host, "deploy@1.2.3.4")

Code.require_file("deploy/tasks.exs", Path.dirname(__ENV__.file))

# expects a config/deploy/Dockerfile
public_task(:build, fn ->
  command("docker container rm dummy", allow_fail: true)
  command("docker build -f config/deploy/Dockerfile  -t #{get(:name)} .")
  command("docker create -ti --name dummy #{get(:name)}:latest bash")
  command("docker cp dummy:/release.tar.gz release.tar.gz")
end)

public_task(:deploy, fn ->
  run(:build)
  run(:upload, ["release.tar.gz", "#{get(:deploy_to)}/release.tar.gz"])
  run(:remote, fn ->
    command("cd #{get(:deploy_to)}")
    command("( [ -d \"bin\" ] && ./bin/#{get(:name)} stop || true )")
    command("tar -zxf release.tar.gz -C .")
    command("./bin/#{get(:name)} daemon")
  end)
end)

Minex.run(System.argv())
```

A public task can be run with `mix minex task_name`, for example:

```
mix minex deploy
```

*Tip:*  in your `mix.exs` you can add aliases for your most used commands. You can for example add `deploy: ["minex deploy"]` and then deploy with `mix deploy`.

## Basics

### Tasks and commands

A normal `task` can only be run internally and not from the command line.

```
task(:my_task, fn ->
  command("...")
  command("...")
  command("...")
end)

```

By default a `command` is run from the local shell. Only if it's included in a `:remote` block, the nested commands will be run over SSH remotely.

```
run(:remote, fn ->
  run(:my_task)
end)
```

If a command results in a non-zero exit code, the rest of the script is aborted (both locally and remotely).

Tasks can accept arguments if needed:

```
task(:my_task, fn [arg] ->
  command("echo #{arg}")
end)

run(:my_task, ["test"])
```

#### Minex defines some base tasks:

Public tasks:

 - `:help` - public task to display the help message (list available public tasks). This is als triggered if you run minex without arguments.
 - `:generate_script` - public task to generate a bash script for the tasks defined with `generate_script_task`.

Helper tasks:

 - `:command` - this task is triggered for each `command()` you call. Can execute locally or remotely, depending on the context.
 - `:remote` - collect all nested commands and execute them on the `:host` over SSH by chaining them.
 - `:upload` - takes a `[local_path, remote_path]` as argument and uses `:scp` to upload the file to the `:host`
 - `:download` -  takes a `[remote_path, local_path]` as argument and uses `:scp` to download the file from the `:host`
 - `:scp` -  takes a `[source, dest]`, so this should include the host. Used by upload and download internally.

 And some internal commands:

 - `:remote_command` - run a single command remotely. Used internally by the `:remote` task.
 - `:local_command` - run a single command locally. Used internally if not in remote mode. This will raise on non-zero exit codes.
 - `:remote_exec` - core task to run a command over SSH. this actually triggers a local `command` that executes `ssh` from the shell.
 - `:local_exec` - core task to run a command locally (uses Erlexec)

### Settings

These settings wills be used by the base tasks:

 - `:host` - target server for remote tasks
 - `:ssh_opts` - string with options for the `ssh` command line call
 - `:scp_opts` - string with options for the `scp` command line call
 - `:remote_command_options` - keyword list of commands options the executing the `ssh` commands locally. Default is `[]`
 - `:local_command_options` - keyword list of basic commands options for all local commands. Default is `[interact: true, echo_cmd: true]`
 - `:generate_script_template` - EEX template that renders the bash script for the `generate_script` command.

Other settings can be defined at will for your own use.

## Advanced usage

### Multiple environments

A common usecase is having multiple environments like staging and production.

A way to support that is by first specifying the environment before you execute a task.

```elixir
use Minex

# ...

args =
  case System.argv() do
    ["staging" | args] ->
      set(:host, "your_staging_host")
      args

    ["production" | args] ->
      set(:host, "your_production_host")
      args

    [_other | _] ->
      raise "please supply an environment as the first argument"

    [] ->
      # allow empty to display help
      []
  end

# Run with the rest of the args
Minex.run(args)
```

### Build on a seperate build server

If you want to run your commands on a seperate build server, you can either change your host to the build server and change it back to the target server later or you can create a specific task to temporarily change the settings:

```elixir
task(:build_server, fn [fun] ->
  # set always returns the old settings of the keys you set
  previous_settings =
    set(
      host: get(:build_server_host),
      ssh_opts: "-i ~/.ssh/build_key"
    )

  run(:remote, fn ->
    fun.()
  end)

  # reset
  set(previous_settings)
end)

run(:build_server, fn ->
  # ...
end)
```

### Use a single SSH connection

To re-use the same connection you can set up a control master. You can do this by specifiying it in your `~/.ssh/config` or by starting it in the task:

```elixir
# Build in settings that are used in the scp/ssh task
set(:ssh_opts, ~s[-o ControlPath=".ssh-control.%h"])
set(:scp_opts, ~s[-o ControlPath=".ssh-control.%h"])

# Start SSH connection in master mode and detach the first time data is received
task(:start_ssh, fn ->
  command("ssh #{get(:ssh_opts)} -TM #{get(:host)}", on_receive: fn _, _ -> :detach end, interact: false)
end)

task(:deploy, fn ->
  run(:build)

  run(:start_ssh)

  # ...
end)
```

### Overriding tasks

It's possible to override the build-in (or your own) tasks:

```elixir
task(:remote_exec, [override: true], fn [command, options] ->
  # your own implementation
end)
```

### Generate script tasks

The `generate_script_task` creates tasks that will be exported to a bash script. This is because for some tasks (like a remote console) you need a full shell/pty and this is not easy to start from the beam.

```elixir
generate_script_task(:iex, fn ->
  run(:remote, fn ->
    command("cd #{get(:deploy_to)} && ./bin/#{get(:name)} remote")
  end)
end)
```

Generate the bash script to a file of your choosing:
```
mix minex generate_script my_script

./my_script iex
```

If you have multiple environments configured:
```
mix minex production generate_script script/production
mix minex staging generate_script script/staging

./script/production iex
```

Note: to create both public and generate_script tasks, you can define them like this:

```elixir
public_task(:name, [generate_script: true], fn ->
  #...
end)
```

### Use a PTY

Some (interactive) commands need a PTY to be present. The enable this:

```
set(:remote_command_options, [pty: true])
set(:ssh_opts, "-t")
```

### Entering passwords

Entering passwords works, but they will be visible in the terminal. The easiest way around this would be `generate_script` tasks and then actually executing the script from the shell.

The other option is grabbing the password with some helper that clears the terminal when typing and then using the `on_receive` option to send the password when needed.

### Semi interactive commands

It's possible to automatically respond to promps by specifying a custom handler in your command. This can be abused to automatically login for example (use at your own risk):

```elixir
public_task(:login_and_ls, fn ->
  on_receive = fn pid, %{buffer: [last | _]} = state ->
    cond do
      last =~ ~r/Permission denied/ ->
        raise("Password failed")

      last =~ ~r/password: $/ ->
        Minex.Command.send_input(pid, "your_password\n")
        {:cont, state}

      true ->
        {:cont, state}
    end
  end

  set(:host, "user_with_password@1.2.3.4")
  set(:remote_command_options, [on_receive: on_receive, pty: true])

  run(:remote, fn ->
    command("ls")
  end)
end)
```

### Dry run

Output the commands that would be executed otherwise:

```elixir
task(:dry_run, fn [fun] ->
  IO.puts "# Dry run:"
  collect(fun)
  |> Enum.join("\n")
  |> IO.puts()
end)

case System.argv() do
  ["dry_run" | args] ->
    run(:dry_run, fn ->
      Minex.run(args)
    end)

  args ->
    Minex.run(args)
end
```

### Local environment variables

Set environment variables for local commands:

Inline:
```elixir
command("VAR=val; echo $VAR")
```

Per command:
```elixir
command("echo $VAR", env: %{"VAR" => "val"})
```

For all commands:
```elixir
set(:local_command_options, [interact: true, echo_cmd: true, env: %{"VAR" => "val"}])
command("echo $VAR")
```

## Acknowledgements

Inspired by the Ruby gem [Mina](https://github.com/mina-deploy/mina) and by [Bootleg](https://github.com/labzero/bootleg)
