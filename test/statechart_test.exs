defmodule ToggleStatechart do
  use Statechart

  statechart default: :on do
    state :on, event: :TOGGLE >>> :off
    state :off, event: :TOGGLE >>> :on
  end
end

defmodule Statechart.StatechartTest do
  use Statechart.Case

  doctest Statechart

  # LATER add statechart/0 to API
  test "Statechart.statechart/0 exists to allow the creation of placeholders" do
    statechart_test_module do: statechart()
  end

  test "Statechart.statechart/X raises if already called in this module" do
    assert_raise StatechartError, ~r/Only one statechart/, fn ->
      statechart_test_module do
        statechart()
        statechart()
      end
    end
  end

  describe "Statechart.statechart/X :default option" do
    test "is required if any states are declared" do
      assert_raise StatechartError, ~r/need to set a default state/, fn ->
        statechart_test_module do
          statechart do
            state :foo
          end
        end
      end
    end

    test "is optional if no states are declared" do
      statechart_test_module do
        statechart do: nil
      end
    end
  end

  test "Statechart.statechart/X :module option wraps chart in the given module" do
    module_name = module_name()
    assert {:module, ^module_name, _, nil} = statechart(module: module_name)
  end

  describe "Statechart.statechart/X :event option" do
    # TODO
    test "works" do
      statechart_test_module mod do
        # LATER use the >>> syntax
        statechart default: :on, event: {:OFF, :off} do
          state :on
          state :off
        end
      end

      mod.new |> assert_state(:on) |> Statechart.trigger(:OFF) |> assert_state(:off)
    end

    test "raises a StatechartError on invalid event names"
    test "an event targetting a branch node must provides a default path to a leaf node"
    test "raises if event targets a root that doesn't resolve"
    test "raises if target does not resolve to a leaf node"

    test "raises if target does not exist" do
      assert_raise StatechartError,
                   ~r/Expected to find a target state with name :does_not_exist/,
                   fn ->
                     statechart module: unique_module_name(),
                                event: :MY_EVENT >>> :does_not_exist do
                       state :alpaca
                     end
                   end
    end
  end

  describe "Statechart.statechart/X :context option" do
    test "is optional, in which case the context defaults to `nil`" do
      statechart_test_module mod do
        statechart do: nil
      end

      mod.new() |> assert_context(nil)
    end

    test "determines the starting context" do
      statechart_test_module mod do
        statechart context: {term, 42}
      end

      mod.new() |> assert_context(42)
    end
  end

  describe "Statechart.statechart/X :entry option" do
    test "transforms the context when machine is instantiated" do
      statechart_test_module mod do
        statechart entry: &List.wrap/1
      end

      mod.new() |> assert_context([])
    end

    test "can take the form &Mod.fun/arity" do
      statechart_test_module mod do
        statechart entry: &List.wrap/1
      end

      mod.new() |> assert_context([])
    end

    test "can take the form &(&1 + 1) or &Mod.fun/arity or fn _ -> _ end" do
      statechart_test_module mod do
        statechart context: {integer, 0},
                   entry: fn int -> int + 1 end,
                   entry: &(&1 * 3),
                   entry: &List.wrap/1
      end

      mod.new() |> assert_context([3])
    end
  end

  test "Statechart.statechart/1 :exit option raises" do
    assert_raise ArgumentError, ~r/Allowed opts for statechart are/, fn ->
      statechart_test_module do
        statechart exit: &List.wrap/1
      end
    end
  end

  test "Statechart.statechart/2 :exit option raises" do
    assert_raise ArgumentError, ~r/Allowed opts for statechart are/, fn ->
      statechart_test_module do
        statechart exit: &List.wrap/1 do
          state :alpaca
        end
      end
    end
  end
end
