defmodule Mix.Tasks.TestSuite do
  use Mix.Task

  @shortdoc "Runs test suite"
  def run([test_suite_url, callback_url, worker_pid | _rest]) do
    CoderunnerSupervisor.start(test_suite_url, callback_url, worker_pid)
  end
end
