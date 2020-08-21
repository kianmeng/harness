defmodule Harness.Renderer do
  @moduledoc """
  Functions for rendering a harness package into the current directory
  """

  alias Harness.Manifest
  alias Harness.Renderer.{Run, File}

  def render(path) when is_binary(path) do
    manifest = Manifest.read(path)

    manifest.generators
    |> Enum.map(&Atom.to_string/1)
    |> Enum.map(&Run.source(&1, manifest.opts, path))
    |> Enum.map(&Run.source_files/1)
    |> Enum.map(&Run.expand_paths/1)
    |> Enum.each(&render/1)
  end

  def render(%Run{} = run) do
    run
    |> into_tree()
    |> generate_tree()
  end

  defp into_tree(%Run{files: rest} = run) do
    root = %File{output_path: ".", type: :directory}
    into_tree(rest, {root, _children = [], run})
  end

  defp into_tree([], {parent, children, run}), do: {parent, sort(children), run}

  defp into_tree([node | rest], {parent, children, run}) do
    if Path.dirname(node.output_path) == parent.output_path do
      into_tree(rest, {parent, [into_tree(rest, {node, [], run}) | children], run})
    else
      into_tree(rest, {parent, children, run})
    end
  end

  defp generate_tree(tree) do
    {_parent, children, run} = tree

    root_node =
      %File{output_path: run.output_directory, type: :directory, root?: true}

    [{root_node, children, run}]
    |> Mix.Utils.print_tree(&tree_node_callback/1, format: "pretty")
  end

  @spec tree_node_callback({%File{}, [%File{}], %Run{}}) :: {{String.t(), String.t()}, [%File{}]}
  defp tree_node_callback({%File{} = parent, children, %Run{} = run}) when is_list(children) do
    {{File.print(parent), File.generate(run, parent)}, children}
  end

  defp sort(children) do
    children
    |> Enum.reverse()
    # puts all the symlinks last
    |> Enum.sort_by(fn {node, _children, _run} -> node.type == :symlink end)
  end
end