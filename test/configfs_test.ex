defmodule Nerves.Runtime.ConfigFSTest do
  use ExUnit.Case
  alias Nerves.Runtime.ConfigFS

  describe "Map to fs overlay" do
    test "single level map" do
      map = %{"/file" => "value"}
      results = ConfigFS.build_manifest(map)
      assert results.files == [{"/file", "value"}]
      # I don't know if this is correct.
      assert results.folders == ["/"]
    end

    test "simple nested maps" do
      map = %{
        "a" => %{"b" => %{"c" => %{"file1" => "data1", "file2" => "data2", "file3" => "data3"}}}
      }
      results = ConfigFS.build_manifest(map)
      assert "/a/b/c" in results.folders
      assert {"/a/b/c/file1", "data1"} in results.files
      assert {"/a/b/c/file2", "data2"} in results.files
      assert {"/a/b/c/file3", "data3"} in results.files
    end

    test "complex multi level map" do
      map = %{
        "level0_path1" => %{"level1_path1_file1" => "level1_path1_file1_value"},
        "level0_path2" => %{
          "level1_path2_file1" => "level1_path2_file1_value",
          "level1_path2_path1" => %{
            "level2_path2_path1_file1" => "level2_path2_path1_file1_value"
          }
        },
        "level0_path3" => %{
          "level1_path3_path1" => %{"level1_path3_path1_path1" => %{}},
          "level1_path3_path2" => %{"level1_path3_path2_path1" => %{"level1_path3_path2_path1_path1" => %{}}},
          "level1_path3_path3" => %{"level1_path3_path3" => %{"level1_path4_path3_file1" => "level1_path4_path3_file1_value"}}
        },
        "level0_empty" => %{},
        "level0_file1" => "level0_file1_value"
      }
      results = ConfigFS.build_manifest(map)
      assert "/level0_path1" in results.folders
      assert "/level0_path2" in results.folders
      assert "/level0_empty" in results.folders
      assert "/level0_path2/level1_path2_path1" in results.folders
      assert "/level0_path3/level1_path3_path2/level1_path3_path2_path1/level1_path3_path2_path1_path1" in results.folders
      assert "/level0_path3/level1_path3_path3/level1_path3_path3" in results.folders

      assert {"/level0_path1/level1_path1_file1", "level1_path1_file1_value"} in results.files
      assert {"/level0_path2/level1_path2_file1", "level1_path2_file1_value"} in results.files
      assert {"/level0_path2/level1_path2_path1/level2_path2_path1_file1", "level2_path2_path1_file1_value"} in results.files
      assert {"/level0_path3/level1_path3_path3/level1_path3_path3/level1_path4_path3_file1", "level1_path4_path3_file1_value"} in results.files

    end

  end
end
