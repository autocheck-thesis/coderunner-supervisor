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
    print("Creating file #{file_name}...")
    file_content = Base.decode64!(contents)
    File.write!("/tmp/coderunner/#{id}/#{file_name}", file_content)
  end

  defp run_tests(%{"image" => image, "steps" => steps}, id) do
    # commands =
    #   Enum.reduce(steps, "", fn x, acc ->
    #     acc <> "\n" <> Enum.join(Map.get(x, "commands"), "\n")
    #   end)

    print("Supervisor OK. Running job '#{id}'.")
    print("Running #{length(steps)} steps...")

    for step <- steps do
      commands = Map.get(step, "commands", [])
      name = Map.get(step, "name", "")

      print("Running step '#{name}'...")

      for command <- commands do
        case command do
          ["run", [cmd]] -> run(image, id, cmd)
          ["print", [string]] -> print(string)
          [key, params] -> print("Invalid command '#{key}' with params '#{params}'")
        end
      end
    end
  end

  defp run(image, id, cmd) do
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
          cmd
        ],
        stderr_to_stdout: true
      )

    IO.binwrite(output)

    if code != 0 do
      print("Exit code: #{code}")
    end
  end

  defp print(string), do: IO.puts(:stderr, string)
end
