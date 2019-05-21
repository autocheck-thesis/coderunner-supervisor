defmodule CoderunnerSupervisor do
  def start(test_data_url, id) do
    HTTPoison.start()

    case HTTPoison.get(test_data_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        test_suite = body |> Jason.decode!()

        File.mkdir!("/tmp/coderunner/#{id}")
        Enum.each(Map.fetch!(test_suite, "files"), &create_file(&1, id))

        run_tests(test_suite, id)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        # {:error, status_code}
        IO.puts("Error: #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        # {:error, reason}
        IO.puts("Error: #{reason}")
    end
  end

  defp create_file(%{"name" => file_name, "contents" => contents}, id) do
    IO.puts(:stderr, "Creating file #{file_name}...")
    file_content = Base.decode64!(contents)
    File.write!("/tmp/coderunner/#{id}/#{file_name}", file_content)
  end

  defp run_tests(%{"image" => image, "steps" => steps}, id) do
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
        [
          "run",
          "-a",
          "STDOUT",
          "-a",
          "STDERR",
          "-v",
          "/tmp/coderunner/#{id}:/tmp/files",
          image,
          "sh",
          "-c",
          commands
        ],
        stderr_to_stdout: true
      )

    IO.binwrite(output)
  end
end
