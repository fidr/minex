defmodule Docker.Sshd do
  def start(debug \\ false) do
    stop(debug)

    exec("cd test/support/sshd && docker build -t sshd:local .", debug)
    |> validate!("Successfully built")

    exec("docker run -d -p 1234:22 sshd:local", debug)
  end

  def stop(debug \\ false) do
    exec("docker stop $(docker ps -q --filter ancestor=sshd:local)", debug)
  end

  defp validate!(output, contains) do
    if !String.contains?(output, contains), do: raise(output)
    output
  end

  defp maybe_debug(output, false), do: output
  defp maybe_debug(output, true), do: IO.inspect(output)

  defp exec(cmd, debug) do
    cmd
    |> String.to_charlist()
    |> :os.cmd()
    |> to_string()
    |> maybe_debug(debug)
  end
end
