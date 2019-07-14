defmodule Mix.Tasks.TestSuite do
  use Mix.Task

  @configuration_file_name "Autocheckfile"

  @shortdoc "Run Autocheck test suite"
  def run(["remote", test_suite_url, callback_url, worker_pid | _rest]) do
    CoderunnerSupervisor.start_remote(test_suite_url, callback_url, worker_pid)
  end

  def run(["local", files_path | _rest]) do
    files_path = Path.expand(files_path)
    configuration_path = Path.join(files_path, @configuration_file_name)

    # NOTE: Keeping the path and configuration path separate to
    # support specifiying separate configuration in the future

    CoderunnerSupervisor.start_local(configuration_path, files_path)
  end

  def run(["local" | _rest]) do
    run(".")
  end

  def run(args) do
    IO.inspect(args)

    IO.puts(:stderr, """
    Error: Must specify remote/local.
    Examples:
    mix test_suite local .
    mix test_suite remote https://example.com/configuration https://example.com/callback
    """)
  end
end
