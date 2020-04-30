defmodule GenerateScriptTest do
  use ExUnit.Case
  import Minex.DSL
  import ExUnit.CaptureIO

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

  test "generate script" do
    generate_script_task(:task_a, fn ->
      run(:remote, fn ->
        command("tail -f tmp/test.log")
      end)
    end)

    generate_script_task(:task_b, fn ->
      run(:remote, fn ->
        command("cd dir && /bin/bash")
      end)
    end)

    public_task(:task_c, fn ->
      run(:remote, fn ->
        command("shouldn't be in there")
      end)
    end)

    tmp_file = Path.join(System.tmp_dir!(), "script")

    output =
      capture_io(fn ->
        Minex.run(["generate_script", "#{tmp_file}"])
      end)

    assert output =~ "#{tmp_file}"

    assert {:ok, script} = File.read(tmp_file)

    assert script === """
           set -e

           case $1 in

             task_a)
               ssh -p 1234 -i test/support/sshd/id_rsa deploy@127.0.0.1 -- $'( tail -f tmp/test.log )'
               ;;

             task_b)
               ssh -p 1234 -i test/support/sshd/id_rsa deploy@127.0.0.1 -- $'( cd dir && /bin/bash )'
               ;;

             *)
               echo "Unknown or missing command, available:
             task_a
             task_b
           "
               ;;
           esac
           """
  end
end
