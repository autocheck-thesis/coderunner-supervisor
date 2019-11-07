defmodule CoderunnerSupervisor do
  alias CoderunnerSupervisor.Runner
  alias Autocheck.Configuration

  def start_remote(configuration_url, callback_url) do
    with {:ok, configuration} <- fetch_remote_configuration(configuration_url) do
      files_path = Path.join("/tmp/coderunner", configuration.job_id)
      create_files(configuration, files_path)

      Runner.start(configuration, files_path, fn result ->
        send_result(result, callback_url)
      end)
    else
      {:error, reason} -> IO.puts(:stderr, "Error: #{reason}")
    end
  end

  def start_local(configuration_path, files_path) do
    try do
      with {:ok, configuration} <- read_configuration(configuration_path) do
        configuration = Map.put(configuration, :job_id, Path.basename(files_path))

        Runner.start(configuration, files_path, fn result ->
          print_result(result)
        end)
      else
        {:error, reason} -> IO.puts(:stderr, "Error: #{reason}")
      end
    rescue
      error in RuntimeError -> IO.puts(:stderr, "Configuration error: #{error.message}")
    end
  end

  def send_result(result, callback_url) do
    HTTPoison.post(callback_url, Jason.encode!(%{result: result}), [
      {"Content-type", "application/json"}
    ])
  end

  defp print_result(result) do
    IO.puts("Results:")

    for %{command_results: command_results, name: name} <- result do
      if command_results_has_error(command_results) do
        IO.puts("\t#{name}: X")

        for %{key: key, params: params, result: result} <- command_results do
          if match?(%{error: error}, result) do
            IO.puts("\t\t#{key}: #{result.error}")
          else
            IO.puts("\t\t#{key}: √")
          end
        end
      else
        IO.puts("\t#{name}: √")
      end
    end
  end

  defp command_results_has_error(command_results) do
    Enum.any?(command_results, &match?(%{result: %{error: _error}}, &1))
  end

  defp read_configuration(path) do
    case File.read(path) do
      {:ok, code} -> {:ok, AutocheckLanguage.parse!(code)}
      {:error, reason} -> {:error, "Could not read #{path} (#{inspect(reason)})"}
    end
  end

  defp fetch_remote_configuration(configuration_url) do
    HTTPoison.start()

    case HTTPoison.get(configuration_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body, keys: :atoms)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp create_files(configuration, path) do
    for file <- configuration.submission_files,
        do: create_file(file, path)

    for file <- configuration.assignment_files,
        do: create_file(file, path, "assignment")
  end

  defp create_file(%{name: filename, contents: contents} = _file, path, basepath \\ "") do
    case sanitize_path(Path.join([basepath, filename]), path) do
      {:ok, path} ->
        # print("Creating path '#{path}'.")
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

  def print(string), do: IO.puts(:stderr, string)
end
