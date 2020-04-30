defmodule SshTest do
  use ExUnit.Case
  import Minex.DSL

  setup_all do
    Docker.Sshd.start()
    on_exit(fn -> Docker.Sshd.stop() end)
    :ok
  end

  setup do
    Minex.start()
    Minex.load_base()
    set(:host, "deploy@127.0.0.1")
    set(:deploy_to, "/home/deploy")
    set(:ssh_opts, "-p 1234 -i test/support/sshd/id_rsa")
    set(:scp_opts, "-P 1234 -i test/support/sshd/id_rsa")
    set(:local_command_options, interact: false, echo_cmd: false)
    :ok
  end

  test "execute command over ssh" do
    task(:pwd, fn ->
      run(:remote, fn ->
        command("pwd")
      end)
    end)

    assert {:ok, "/home/deploy\n"} = run(:pwd)
  end

  test "multiple successful commands" do
    task(:pwd, fn ->
      run(:remote, fn ->
        command("var=test")
        command("echo $var")
      end)
    end)

    assert {:ok, "test\n"} = run(:pwd)
  end

  test "failure aborts the chain" do
    task(:pwd, fn ->
      run(:remote, fn ->
        command("pwd")
        command("false")
        command("echo test")
      end)
    end)

    assert_raise(RuntimeError, ~r/Command failed/, fn -> run(:pwd) end)
  end

  test "remote with subshell" do
    task(:script, fn ->
      run(:remote, fn ->
        command("echo test1")
        command("( exit )")
        command("echo test2")
      end)
    end)

    assert {:ok, "test1\ntest2\n"} = run(:script)
  end
end
