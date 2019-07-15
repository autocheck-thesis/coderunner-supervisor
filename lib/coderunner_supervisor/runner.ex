defmodule CoderunnerSupervisor.Runner do
  @container_path "/tmp/coderunner"

  import CoderunnerSupervisor, only: [print: 1]

  # defined in seconds
  @container_sleep_duration 10 * 60

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
          "sleep #{@container_sleep_duration}"
        ],
        stderr_to_stdout: true,
        into: []
      )

    output
    |> Enum.take(-1)
    |> hd()
    |> String.trim()
  end

  defp kill_container(container_id) do
    System.cmd(
      "docker",
      [
        "kill",
        container_id
      ],
      stderr_to_stdout: true
    )
  end

  def start(
        %{image: image, steps: steps, job_id: job_id} = configuration,
        files_path,
        result_callback
      ) do
    # commands =
    #   Enum.reduce(steps, "", fn x, acc ->
    #     acc <> "\n" <> Enum.join(Map.get(x, "commands"), "\n")
    #   end)

    print("Creating container. This can take a while.")
    container_id = create_container(job_id, image)

    print("Copying files into container.")
    copy_files(container_id, files_path, @container_path)

    print("Details:")
    print("Job:\t\t#{job_id}")
    print("Container:\t#{container_id}")
    print("Image:\t\t#{image}")

    if step_count = length(steps) do
      print("Running #{step_count} steps.")
    else
      print("No steps defined.")
    end

    results = steps |> Enum.map(&run_step(container_id, &1))
    result_callback.(results)

    print("Stopping container.")
    kill_container(container_id)
  end

  defp run_step(container_id, step) do
    commands = Map.get(step, :commands, [])
    name = Map.get(step, :name, "")

    print("Step #{name}")

    %{
      name: name,
      command_results: commands |> Enum.map(&run_command(container_id, &1))
    }
  end

  defp run_command(container_id, [key, params] = command) do
    %{
      key: key,
      params: params,
      result: command(key, params, container_id)
    }
  end

  defp command("run", [cmd], container_id) do
    {_output, exit_code} =
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

    case exit_code do
      0 -> true
      _ -> %{error: "Non-zero exit code: #{exit_code}"}
    end
  end

  defp command("print", [string], _container_id) do
    print(string)

    true
  end

  defp command(key, params, _container_id) do
    msg = "Invalid command '#{key}' with params '#{params}'"
    print(msg)

    %{error: msg}
  end
end
