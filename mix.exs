defmodule ExlaPrecompiled.MixProject do
  use Mix.Project

  def project do
    if Mix.env() == :prod do
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

  defp init() do
    root_project_path = Path.expand("../..", __DIR__)
    deps_path = Path.join(root_project_path, "deps")
    exla_path = Path.join(deps_path, "exla/exla")
    libexla_path = Path.join([exla_path, "priv", nif_filename()])

    if File.exists?(exla_path) and not File.exists?(libexla_path) do
      tag = release_tag_for_project(root_project_path)

      Mix.shell("No exla binary found locally, trying find one online...")

      case download_binary(tag, libexla_path) do
        :ok ->
          Mix.shell().info("Successfully downloaded precompiled exla binary!")
          Mix.shell().info("Altering exla Makefile to avoid regular compilation")

          # Replace Makefile, so that a regular compilation doesn't proceed
          for makefile_name <- ["Makefile", "Makefile.win"] do
            makefile_path = Path.join(exla_path, makefile_name)
            File.rename!(makefile_path, makefile_path <> ".original")
            # Keep an empty Makefile, so that elixir_make doesn't error out
            File.write!(makefile_path, "noop: ;")
          end

        :error ->
          Mix.shell().info(
            "Couldn't find a matching precompiled exla binary, will need to compile"
          )
      end
    end
  end

  defp release_tag_for_project(project_path) do
    sha = exla_sha_in_project(project_path)
    "sha/" <> sha
  end

  defp exla_sha_in_project(project_path) do
    lock_path = Path.expand("mix.lock", project_path)

    {:%{}, _, entries_ast} =
      lock_path
      |> File.read!()
      |> Code.string_to_quoted!(warn_on_unnecessary_quotes: false)

    {:{}, _, [:git, _url, sha | _]} = entries_ast[:exla]

    sha
  end

  defp download_binary(tag, destination_path) do
    repo = "jonatanklosko/exla_precompiled"
    url = "https://github.com/#{repo}/releases/download/#{tag}/#{nif_filename_with_target()}"
    File.mkdir_p!(Path.dirname(destination_path))
    download(url, destination_path)
  end

  defp download(url, dest) do
    case Mix.shell().cmd("curl --fail -L #{url} > #{dest}") do
      0 -> :ok
      _ -> :error
    end
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
    case :string.split(:erlang.system_info(:system_architecture), '-', :all) do
      [cpu, _vendor, os | _] ->
        os = if List.starts_with?(os, 'darwin'), do: 'darwin', else: os
        cpu = if os == 'darwin' and List.starts_with?(cpu, 'arm'), do: 'aarch64', else: cpu
        "#{cpu}-#{os}"

      ['win32'] ->
        "x86_64-windows"
    end
  end
end
