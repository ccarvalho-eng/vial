defmodule Mix.Tasks.Vial.BuildAssets do
  @moduledoc """
  Build and compile assets for the Vial embedded library.

  This task compiles CSS and JavaScript assets and places them in
  priv/static/vial/ for distribution with the hex package.

  ## Usage

      mix vial.build_assets

  ## What it does

  1. Runs esbuild to compile JavaScript
  2. Runs tailwind to compile CSS
  3. Copies compiled assets to priv/static/vial/
  4. Generates a manifest file for asset versioning
  """

  use Mix.Task

  @shortdoc "Build Vial assets for distribution"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Building Vial assets...")

    # Ensure we're in the right directory
    File.cd!(File.cwd!())

    # Create target directory
    target_dir = "priv/static/vial"
    File.rm_rf!(target_dir)
    File.mkdir_p!(target_dir)
    File.mkdir_p!("#{target_dir}/js")
    File.mkdir_p!("#{target_dir}/css")
    File.mkdir_p!("#{target_dir}/images")
    File.mkdir_p!("#{target_dir}/fonts")

    # Build JavaScript
    Mix.shell().info("Compiling JavaScript...")
    build_javascript(target_dir)

    # Build CSS
    Mix.shell().info("Compiling CSS...")
    build_css(target_dir)

    # Copy other static assets
    Mix.shell().info("Copying static assets...")
    copy_static_assets(target_dir)

    # Generate manifest
    Mix.shell().info("Generating manifest...")
    generate_manifest(target_dir)

    Mix.shell().info("✅ Assets built successfully!")
  end

  defp build_javascript(target_dir) do
    # Use Mix.Task to run esbuild
    args = [
      "assets/js/app.js",
      "--bundle",
      "--minify",
      "--target=es2022",
      "--outfile=#{target_dir}/js/app.js",
      "--external:/fonts/*",
      "--external:/images/*"
    ]

    # esbuild executable is in _build/ directory
    build_path = Mix.Project.build_path() |> Path.dirname()
    esbuild_path = Path.join(build_path, "esbuild-#{esbuild_target()}")

    System.cmd(esbuild_path, args, cd: File.cwd!(), into: IO.stream(:stdio, :line))

    # Also copy any hooks or vendor scripts
    copy_if_exists("assets/vendor/topbar.js", "#{target_dir}/js/topbar.js")
  end

  defp build_css(target_dir) do
    # Use Mix.Task to run tailwind
    args = [
      "--input=assets/css/app.css",
      "--output=#{target_dir}/css/app.css"
      # Don't minify - minification removes custom CSS
    ]

    # tailwind executable is in _build/ directory
    build_path = Mix.Project.build_path() |> Path.dirname()
    tailwind_path = Path.join(build_path, "tailwind-#{tailwind_target()}")

    System.cmd(tailwind_path, args, cd: File.cwd!(), into: IO.stream(:stdio, :line))
  end

  defp esbuild_target do
    case :os.type() do
      {:win32, _} -> "windows-x64.exe"
      {:unix, :darwin} -> if mac_arm64?(), do: "darwin-arm64", else: "darwin-x64"
      {:unix, :linux} -> if linux_arm64?(), do: "linux-arm64", else: "linux-x64"
    end
  end

  defp tailwind_target do
    # Note: tailwind executable is named differently than esbuild
    case :os.type() do
      {:win32, _} -> "windows-x64.exe"
      {:unix, :darwin} -> if mac_arm64?(), do: "macos-arm64", else: "macos-x64"
      {:unix, :linux} -> if linux_arm64?(), do: "linux-arm64", else: "linux-x64"
    end
  end

  defp mac_arm64? do
    :erlang.system_info(:system_architecture)
    |> to_string()
    |> String.contains?("aarch64")
  end

  defp linux_arm64? do
    :erlang.system_info(:system_architecture)
    |> to_string()
    |> String.contains?("aarch64")
  end

  defp copy_static_assets(target_dir) do
    # Copy images if they exist
    if File.exists?("priv/static/images") do
      File.cp_r!("priv/static/images", "#{target_dir}/images")
    end

    # Copy fonts if they exist
    if File.exists?("priv/static/fonts") do
      File.cp_r!("priv/static/fonts", "#{target_dir}/fonts")
    end

    # Copy any other necessary static files
    copy_if_exists("priv/static/robots.txt", "#{target_dir}/robots.txt")
    copy_if_exists("priv/static/favicon.ico", "#{target_dir}/favicon.ico")
  end

  defp generate_manifest(target_dir) do
    # Generate a simple manifest with file hashes for cache busting
    files =
      Path.wildcard("#{target_dir}/**/*")
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn file ->
        relative_path = Path.relative_to(file, target_dir)
        hash = file_hash(file)
        {relative_path, hash}
      end)
      |> Map.new()

    manifest = %{
      version: "1.0.0",
      files: files
    }

    File.write!("#{target_dir}/manifest.json", Jason.encode!(manifest, pretty: true))
  end

  defp file_hash(path) do
    {:ok, content} = File.read(path)
    :crypto.hash(:md5, content) |> Base.encode16(case: :lower) |> String.slice(0..7)
  end

  defp copy_if_exists(source, destination) do
    if File.exists?(source) do
      File.cp!(source, destination)
    end
  end
end
