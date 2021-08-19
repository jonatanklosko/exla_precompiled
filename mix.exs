defmodule ExlaPrecompiled.MixProject do
  use Mix.Project

  @github_repo "jonatanklosko/exla_precompiled"

  def project do
    if Mix.env() == :prod and not skip?() do
      init()
    end

    [
      app: :exla_precompiled,
      version: "0.1.0-dev",
      elixir: "~> 1.12",
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:exla, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "exla", only: [:dev]},
      {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "nx", override: true, only: [:dev]}
    ]
  end

  defp aliases do
    [
      "build.release_tag": &build_release_tag/1,
      "build.release_nif_filename": &build_release_nif_filename/1,
      "build.nif_path": &build_nif_path/1
    ]
  end

  # Aliases used by the build scripts

  defp build_release_tag(_) do
    IO.puts(release_tag_for_project(__DIR__))
  end

  defp build_release_nif_filename(_) do
    IO.puts(nif_filename_with_target())
  end

  defp build_nif_path(_) do
    exla_path = Path.expand("deps/exla/exla", __DIR__)
    nif_path = Path.join([exla_path, "priv", nif_filename()])
    IO.puts(nif_path)
  end

  # ---

  defp skip?() do
    System.get_env("SKIP_EXLA_PRECOMPILED") == "true"
  end

  defp init() do
    root_project_path = Path.expand("../..", __DIR__)
    deps_path = Path.join(root_project_path, "deps")
    exla_path = Path.join(deps_path, "exla/exla")
    libexla_path = Path.join([exla_path, "priv", nif_filename()])

    if File.exists?(exla_path) and not File.exists?(libexla_path) do
      tag = release_tag_for_project(root_project_path)
      expected_filename = nif_filename_with_target()

      unless network_tool() do
        exit_with_reason!(
          "Expected either curl or wget to be available in your system, but neither was found"
        )
      end

      Mix.shell().info("No exla binary found locally, trying find a precompiled one online. 🕵️")

      filenames =
        case list_release_files(tag) do
          {:ok, filenames} ->
            filenames

          :error ->
            exit_with_reason!(
              "No precompiled binaries found for your exla version. " <>
                "Visit https://github.com/#{@github_repo}/releases for supported versions"
            )
        end

      unless expected_filename in filenames do
        exit_with_reason!(
          "Found precompiled binaries for your exla version, but none matches your target.\n" <>
            "  Expected: #{expected_filename}\n" <>
            "  Found: #{Enum.join(filenames, ", ")}\n" <>
            "If it is ERTS version mismatch, you can just update Erlang/OTP locally."
        )
      end

      Mix.shell().info("Found a matching binary, going to download it. 🚀")

      if download_release_file(tag, expected_filename, libexla_path) == :error do
        exit_with_reason!("Failed to download the binary.")
      end

      Mix.shell().info("Successfully downloaded the binary! 🐈")

      Mix.shell().info("Altering exla Makefile to avoid regular compilation. 📝")
      neutralize_makefile!(exla_path)

      Mix.shell().info("You are all set! 🚢")
    end
  end

  defp exit_with_reason!(message) do
    Mix.shell().info(message)

    Mix.shell().info(
      "You can also proceed to regular compilation by setting SKIP_EXLA_PRECOMPILED=true environment variable."
    )

    System.halt()
  end

  defp release_tag_for_project(project_path) do
    sha = exla_sha_in_project(project_path)
    "sha/" <> sha
  end

  defp exla_sha_in_project(project_path) do
    exla_path = Path.join(project_path, "deps/exla")
    {sha, 0} = System.shell("git rev-parse HEAD", cd: exla_path)
    String.trim(sha)
  end

  defp nif_filename() do
    "libexla.#{nif_ext()}"
  end

  defp nif_filename_with_target() do
    "libexla-#{target()}.#{nif_ext()}"
  end

  defp nif_ext() do
    case :os.type() do
      {:unix, _} -> "so"
      {:win32, _} -> "dll"
    end
  end

  defp target() do
    erts_version = :erlang.system_info(:version)

    {cpu, os} =
      :erlang.system_info(:system_architecture)
      |> List.to_string()
      |> String.split("-")
      |> case do
        ["arm" <> _, _vendor, "darwin" <> _ | _] -> {"aarch64", "darwin"}
        [cpu, _vendor, "darwin" <> _ | _] -> {cpu, "darwin"}
        [cpu, _vendor, os | _] -> {cpu, os}
        ["win32"] -> {"x86_64", "windows"}
      end

    "#{cpu}-#{os}-erts-#{erts_version}"
  end

  defp neutralize_makefile!(exla_path) do
    # Replace Makefile, so that a regular compilation doesn't proceed
    for makefile_name <- ["Makefile", "Makefile.win"] do
      makefile_path = Path.join(exla_path, makefile_name)
      File.rename!(makefile_path, makefile_path <> ".original")
      # Keep an empty Makefile, so that elixir_make doesn't error out
      File.write!(makefile_path, "noop: ;")
    end
  end

  # Requests

  defp list_release_files(tag) do
    url = "https://api.github.com/repos/#{@github_repo}/releases/tags/#{tag}"

    with {:ok, body} <- get(url) do
      # We don't have a JSON library available here, so we do
      # a simple matching
      {:ok, Regex.scan(~r/"name":\s+"(.*\.(?:so|ddl))"/, body) |> Enum.map(&Enum.at(&1, 1))}
    end
  end

  defp download_release_file(tag, filename, destination_path) do
    url = "https://github.com/#{@github_repo}/releases/download/#{tag}/#{filename}"
    File.mkdir_p!(Path.dirname(destination_path))
    download(url, destination_path)
  end

  defp download(url, dest) do
    command =
      case network_tool() do
        :curl -> "curl --fail -L #{url} -o #{dest}"
        :wget -> "wget -O #{dest} #{url}"
      end

    case System.shell(command) do
      {_, 0} -> :ok
      _ -> :error
    end
  end

  defp get(url) do
    command =
      case network_tool() do
        :curl -> "curl --fail --silent -L #{url}"
        :wget -> "wget -q -O - #{url}"
      end

    case System.shell(command) do
      {body, 0} -> {:ok, body}
      _ -> :error
    end
  end

  defp network_tool() do
    cond do
      executable_exists?("curl") -> :curl
      executable_exists?("wget") -> :wget
      true -> nil
    end
  end

  defp executable_exists?(name), do: System.find_executable(name) != nil
end
