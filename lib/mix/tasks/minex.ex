defmodule Mix.Tasks.Minex do
  use Mix.Task

  @config_file "config/deploy.exs"

  @shortdoc "Call minex"
  def run(args) do
    if !File.exists?(@config_file) do
      Mix.raise "Failed to find '#{@config_file}', run 'mix minex.init' to initialize"
    end

    Mix.Tasks.Run.run([@config_file | args])
  end
end
