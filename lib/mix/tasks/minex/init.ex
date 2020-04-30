defmodule Mix.Tasks.Minex.Init do
  use Mix.Task

  @shortdoc "Initialize minex, create deploy config"
  def run(_) do
    context = template_context()

    source_file = Path.join([priv_dir(), "templates", "deploy.exs.eex"])
    content = EEx.eval_file(source_file, context)
    Mix.Generator.create_file("config/deploy.exs", content)

    source_file = Path.join([priv_dir(), "templates", "tasks.exs.eex"])
    content = EEx.eval_file(source_file, context)
    Mix.Generator.create_file("config/deploy/tasks.exs", content)
  end

  defp priv_dir() do
    :code.priv_dir(:minex)
  end

  defp template_context() do
    config = Mix.Project.config()
    app = config |> Keyword.fetch!(:app)
    app_module = app |> to_string() |> Macro.camelize()

    [
      app: app,
      app_module: app_module
    ]
  end
end
