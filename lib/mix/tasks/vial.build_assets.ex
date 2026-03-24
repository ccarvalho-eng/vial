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
    # Build the main app.js bundle
    System.cmd(
      "npx",
      [
        "esbuild",
        "assets/js/app.js",
        "--bundle",
        "--minify",
        "--target=es2022",
        "--outfile=#{target_dir}/js/app.js",
        "--external:/fonts/*",
        "--external:/images/*"
      ], cd: ".", into: IO.stream(:stdio, :line))

    # Also copy any hooks or vendor scripts
    copy_if_exists("assets/vendor/topbar.js", "#{target_dir}/js/topbar.js")
  end

  defp build_css(target_dir) do
    # First, generate the Tailwind CSS with Vial-specific prefix to avoid conflicts
    content = """
    @config "../../assets/tailwind.config.js";
    @import "../../assets/css/app.css";
    """

    # Create a temporary file with the prefixed config
    tmp_file = "tmp_vial_tailwind.css"
    File.write!(tmp_file, content)

    # Run Tailwind with custom config
    System.cmd(
      "npx",
      [
        "tailwindcss",
        "-i",
        tmp_file,
        "-o",
        "#{target_dir}/css/app.css",
        "--minify"
      ], cd: ".", into: IO.stream(:stdio, :line))

    # Clean up temp file
    File.rm!(tmp_file)
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
