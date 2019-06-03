defmodule CoderunnerSupervisor do
  def start(test_data_url) do
    HTTPoison.start()

    case HTTPoison.get(test_data_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        test_suite = body |> Jason.decode!()

        job_id = Map.fetch!(test_suite, "job_id")

        File.mkdir!("/tmp/coderunner/#{job_id}")
        Enum.each(Map.fetch!(test_suite, "files"), &create_file(&1, job_id))

        run_tests(test_suite, job_id)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        # {:error, status_code}
        IO.puts("Error: #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        # {:error, reason}
        IO.puts("Error: #{reason}")
    end
  end

  defp create_file(%{"name" => filename, "contents" => contents}, job_id) do
    case sanitize_path(filename, "/tmp/coderunner/#{job_id}") do
      {:ok, path} ->
        print("Creating path '#{path}'.")
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, Base.decode64!(contents))

      :error ->
        print("Invalid filename: '#{filename}'")
    end
  end

  @doc """

  Sanitize file path. Used to protect against malicious traversals, etc...

  ## Examples

    iex> CoderunnerSupervisor.sanitize_path("bar.txt", "/tmp/coderunner/foo")
    {:ok, "/tmp/coderunner/foo/bar.txt"}

    iex> CoderunnerSupervisor.sanitize_path("../bar.txt", "/tmp/coderunner/foo")
    :error

    iex> CoderunnerSupervisor.sanitize_path("relative_path/../bar.txt", "/tmp/coderunner/foo")
    {:ok, "/tmp/coderunner/foo/bar.txt"}

    iex> CoderunnerSupervisor.sanitize_path("../../../bar.txt", "/tmp/coderunner/foo")
    :error

  """
  def sanitize_path(path, rootdir) do
    expanded_path = Path.expand(path, rootdir)

    case String.starts_with?(expanded_path, Path.expand(rootdir)) do
      true -> {:ok, expanded_path}
      false -> :error
    end
  end

  defp run_tests(%{"image" => image, "steps" => steps}, job_id) do
    # commands =
    #   Enum.reduce(steps, "", fn x, acc ->
    #     acc <> "\n" <> Enum.join(Map.get(x, "commands"), "\n")
    #   end)

    print("Supervisor OK. Running job '#{job_id}' within '#{image}'")
    print("Running #{length(steps)} steps...")

    for step <- steps do
      commands = Map.get(step, "commands", [])
      name = Map.get(step, "name", "")

      print("Running step '#{name}'...")

      for command <- commands do
        case command do
          ["run", [cmd]] -> run(image, job_id, cmd)
          ["print", [string]] -> print(string)
          [key, params] -> print("Invalid command '#{key}' with params '#{params}'")
        end
      end
    end
  end

  defp run(image, job_id, cmd) do
    {output, code} =
      System.cmd(
        "docker",
        [
          "run",
          "--rm",
          "-a",
          "STDOUT",
          "-a",
          "STDERR",
          "-v",
          "/tmp/coderunner/#{job_id}:/tmp/files",
          "-w",
          "/tmp/files",
          image,
          "sh",
          "-c",
          cmd
        ],
        stderr_to_stdout: true
      )

    IO.write(output)

    if code != 0 do
      print("Exit code: #{code}")
    end
  end

  defp print(string), do: IO.puts(:stderr, string)
end
