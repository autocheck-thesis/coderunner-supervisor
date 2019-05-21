defmodule Mix.Tasks.TestSuite do
  use Mix.Task

  @shortdoc "Runs test suite"
  def run([test_suite_url | [submission_id]]) do
    CoderunnerSupervisor.start(test_suite_url, submission_id)
  end
end
