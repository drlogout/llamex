defmodule Llamex.ChecksTest do
  use ExUnit.Case, async: true

  alias Credo.SourceFile

  test "exposes the shipped check modules" do
    assert Llamex.checks() == [
             Llamex.Check.NoOneLiners,
             Llamex.Check.NoAdHocAshQueries,
             Llamex.Check.ConsistentInterfaces,
             Llamex.Check.NoDBWorkInMemory
           ]
  end

  test "registers all checks through the Credo plugin entry point" do
    exec =
      Credo.Execution.build([])
      |> Credo.Execution.set_initializing_plugin(Llamex.Plugin)
      |> Llamex.Plugin.init()

    plugin_config =
      exec
      |> Credo.Execution.get_config_files()
      |> Enum.find(fn
        {:plugin, Llamex.Plugin, _config} -> true
        _ -> false
      end)

    assert {:plugin, Llamex.Plugin, config} = plugin_config

    assert config =~ "{Llamex.Check.NoOneLiners, []}"
    assert config =~ "{Llamex.Check.NoAdHocAshQueries, []}"
    assert config =~ "{Llamex.Check.ConsistentInterfaces, []}"
    assert config =~ "{Llamex.Check.NoDBWorkInMemory, []}"

    assert {:ok, config_file} =
             Credo.ConfigFile.read_or_default(exec, File.cwd!(), "default", false)

    assert {Llamex.Check.NoOneLiners, []} in config_file.checks.extra
    assert {Llamex.Check.NoAdHocAshQueries, []} in config_file.checks.extra
    assert {Llamex.Check.ConsistentInterfaces, []} in config_file.checks.extra
    assert {Llamex.Check.NoDBWorkInMemory, []} in config_file.checks.extra
  end

  defp issues(check, source, params \\ []) do
    source
    |> SourceFile.parse("lib/sample.ex")
    |> check.run(params)
  end

  defp messages(issues), do: Enum.map(issues, & &1.message)

  describe "NoOneLiners" do
    test "flags trivial one-line and assign-return wrappers" do
      source = """
      defmodule Sample do
        def search_for_record(id), do: Search.search_for_record(id)

        def get_record(id) do
          value = Search.get_one_record!(id)
          {:ok, value}
        end
      end
      """

      issues = issues(Llamex.Check.NoOneLiners, source)

      assert length(issues) == 2
      assert Enum.all?(messages(issues), &String.contains?(&1, "Redundant one-line wrapper"))
    end

    test "allows callbacks and wrappers with rescue" do
      source = """
      defmodule Sample do
        def handle_event("search:" <> event, params, socket) do
          Search.handle_input(event, params, socket)
        end

        def search_for_record(id) do
          Search.search_for_record!(id)
        rescue
          error -> {:error, error}
        end
      end
      """

      assert [] = issues(Llamex.Check.NoOneLiners, source)
    end
  end

  describe "NoAdHocAshQueries" do
    test "flags direct query and execution APIs outside Ash implementation modules" do
      source = """
      defmodule Sample do
        def create_ticket(params) do
          Helpdesk.Support.Ticket
          |> Ash.Changeset.for_create(:open, params)
          |> Ash.create!()
        end
      end
      """

      assert [first | _] = issues(Llamex.Check.NoAdHocAshQueries, source)
      assert first.message =~ "Avoid ad-hoc queries"
    end

    test "allows aggregate terminal calls and Ash implementation modules" do
      aggregate = """
      defmodule Sample do
        def count_tickets do
          Helpdesk.Support.list_all_tickets()
          |> Ash.count!()
        end
      end
      """

      implementation_module = """
      defmodule Sample.Change do
        use Ash.Resource.Change

        def change(changeset, _opts, %{actor: %{id: actor_id}}) do
          Ash.Changeset.force_change_attribute(changeset, :submitter_id, actor_id)
        end
      end
      """

      assert [] = issues(Llamex.Check.NoAdHocAshQueries, aggregate)
      assert [] = issues(Llamex.Check.NoAdHocAshQueries, implementation_module)
    end

    test "flags inline ad-hoc query options on domain interface calls" do
      source = """
      defmodule Sample do
        def get_records_for_user(id) do
          Helpdesk.Support.get_user_records!(id, load: [:comments], offset: 20)
        end
      end
      """

      assert [issue] = issues(Llamex.Check.NoAdHocAshQueries, source)
      assert issue.message =~ "Avoid ad-hoc queries"
    end
  end

  describe "ConsistentInterfaces" do
    test "flags interface defines whose name differs from the action" do
      source = """
      defmodule Helpdesk.Support do
        use Ash.Domain

        resources do
          resource Helpdesk.Support.Ticket do
            define :suggest_card_size_matches,
              action: :list_and_suggest_matched_cards,
              args: [:input]
          end
        end
      end
      """

      assert [issue] = issues(Llamex.Check.ConsistentInterfaces, source)
      assert issue.message =~ "suggest_card_size_matches"
      assert issue.message =~ "list_and_suggest_matched_cards"
    end

    test "allows matching interface and action names" do
      source = """
      defmodule Helpdesk.Support do
        use Ash.Domain

        resources do
          resource Helpdesk.Support.Ticket do
            define :list_and_suggest_matched_cards,
              action: :list_and_suggest_matched_cards,
              args: [:input]
          end
        end
      end
      """

      assert [] = issues(Llamex.Check.ConsistentInterfaces, source)
    end
  end

  describe "NoDBWorkInMemory" do
    test "flags Enum work on values from Ash-style domain interfaces" do
      source = """
      defmodule Sample do
        alias Helpdesk.Support.Books

        def show_invalid_records do
          books = Books.get_all_books!()

          books
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&(&1.status == :invalid))
        end
      end
      """

      assert [issue | _] = issues(Llamex.Check.NoDBWorkInMemory, source)
      assert issue.message =~ "Do not operate on the whole dataset in memory"
      assert issue.message =~ "Books.get_all_books!"
    end

    test "honors the Llamex opt-out attribute" do
      source = """
      defmodule Sample do
        @llamex_db_work_in_memory_allowed true

        def show_invalid_records do
          Books.get_all_books!()
          |> Enum.filter(&(&1.status == :invalid))
        end
      end
      """

      assert [] = issues(Llamex.Check.NoDBWorkInMemory, source)
    end
  end
end
