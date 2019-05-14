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

    {output, exit_code} = System.cmd("docker", ["run", "-i", image, "sh", "-c", commands])
    IO.puts(output)
  end
end
