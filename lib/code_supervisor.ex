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

    IO.puts(:stderr, "Creating image...")

    {output, _} = System.cmd("docker", ["create", "-i", image, "sh", "-c", commands])

    IO.puts(:stderr, "Running image...")

    path = System.find_executable("docker")

    Port.open({:spawn_executable, path}, [
      :stderr_to_stdout,
      :binary,
      :exit_status,
      args: ["start", "-i", String.trim(output)]
    ])
    |> stream_output()
  end

  defp stream_output(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        stream_output(port)

      {^port, {:exit_status, 0}} ->
        IO.puts(:stderr, "Command success")

      {^port, {:exit_status, status}} ->
        IO.puts(:stderr, "Command error, status #{status}")
    end
  end
end
