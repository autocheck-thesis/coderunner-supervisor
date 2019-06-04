defmodule CoderunnerSupervisor do
  @host_path "/tmp/coderunner"
  @container_path "/tmp/coderunner"

  def start(test_data_url) do
    HTTPoison.start()

    case HTTPoison.get(test_data_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        test_suite = body |> Jason.decode!()

        job_id = Map.fetch!(test_suite, "job_id")
        create_files(test_suite, job_id)
        run_tests(test_suite, job_id)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        # {:error, status_code}
        IO.puts("Error: #{status_code}")

      {:error, %HTTPoison.Error{reason: reason}} ->
        # {:error, reason}
        IO.puts("Error: #{reason}")
    end
  end

  defp create_files(test_suite, job_id) do
    for file <- Map.fetch!(test_suite, "files"), do: create_file(file, job_id)
  end

  defp create_file(%{"name" => filename, "contents" => contents}, job_id) do
    case sanitize_path(filename, Path.join(@host_path, job_id)) do
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

  defp copy_files(container_name, host_path, child_path) do
    System.cmd(
      "docker",
      [
        "cp",
        host_path,
        [container_name, child_path] |> Enum.join(":")
      ],
      stderr_to_stdout: true
    )
  end

  defp create_container(job_id, image) do
    {output, _code} =
      System.cmd(
        "docker",
        [
          "run",
          "--rm",
          "-d",
          "-w",
          Path.join(@container_path, job_id),
          image,
          "/bin/sh",
          "-c",
          "sleep 3600"
        ],
        stderr_to_stdout: true
      )

    String.trim(output)
  end

  defp stop_container(container_id) do
    System.cmd(
      "docker",
      [
        "stop",
        container_id
      ],
      stderr_to_stdout: true
    )
  end

  defp run_tests(%{"image" => image, "steps" => steps}, job_id) do
    # commands =
    #   Enum.reduce(steps, "", fn x, acc ->
    #     acc <> "\n" <> Enum.join(Map.get(x, "commands"), "\n")
    #   end)

    print("Creating container.")
    container_id = create_container(job_id, image)

    print("Copying files into container.")
    copy_files(container_id, Path.join(@host_path, job_id), @container_path)

    print("Details:")
    print("Job:\t\t#{job_id}")
    print("Container:\t#{container_id}")
    print("Image:\t\t#{image}")

    if step_count = length(steps) do
      print("Running #{step_count} steps.")

      for step <- steps do
        commands = Map.get(step, "commands", [])
        name = Map.get(step, "name", "")

        print("#{name}")

        for command <- commands do
          case command do
            ["run", [cmd]] -> run(container_id, cmd)
            ["print", [string]] -> print(string)
            [key, params] -> print("Invalid command '#{key}' with params '#{params}'")
          end
        end
      end
    else
      print("No steps defined.")
    end

    print("Stopping container.")

    stop_container(container_id)
  end

  defp run(container_id, cmd) do
    {_output, code} =
      System.cmd(
        "docker",
        [
          "exec",
          # "-t",
          "-i",
          container_id,
          "sh",
          "-c",
          cmd
        ],
        stderr_to_stdout: true,
        into: IO.stream(:stdio, :line)
      )

    if code != 0 do
      print("Exit code: #{code}")
    end
  end

  defp print(string), do: IO.puts(:stderr, string)
end
