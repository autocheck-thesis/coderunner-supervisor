defmodule CoderunnerSupervisor.MixProject do
  use Mix.Project

  def project do
    [
      app: :coderunner_supervisor,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.5.1"},
      {:jason, "~> 1.1"},
      {:autocheck_language, path: "../language"},
      {:distillery, "~> 2.1"}
    ]
  end
end
