defmodule CoderunnerSupervisor do
  def start(test_data_url) do
    HTTPoison.start()

    case HTTPoison.get(test_data_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> run_tests()

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        # {:error, status_code}
        IO.puts("Error: #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        # {:error, reason}
        IO.puts("Error: #{reason}")
    end
  end

  defp run_tests(%{"image" => image, "steps" => steps}) do
    commands =
      Enum.reduce(steps, "", fn x, acc ->
        acc <> "\n" <> Enum.join(Map.get(x, "commands"), "\n")
      end)

    IO.puts(:stderr, "Running image...")

    # port =
    #   Port.open({:spawn_executable, System.find_executable("docker")}, [
    #     :stderr_to_stdout,
    #     # :binary,
    #     :exit_status,
    #     args: ["run", "-a", "STDOUT", "-a", "STDERR", image, "sh", "-c", commands]
    #   ])

    # stream_output(port)

    {output, code} =
      System.cmd(
        "docker",
        ["run", "-a", "STDOUT", "-a", "STDERR", image, "sh", "-c", commands],
        stderr_to_stdout: true
      )

    IO.binwrite(output)
  end
end
