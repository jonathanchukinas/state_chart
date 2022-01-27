defmodule Statechart.MachineTest do
  # Even though this module references Statechart.Machine,
  # it's testing the Statechart API, which delegates out to it.

  use ExUnit.Case
  use Statechart
  alias Statechart.Machine

  def print_notice(_), do: IO.puts("Exiting the light cycle")
  # LATER introduce subchart
  statechart module: LightCycle, default: :red do
    # LATER this is ugly behaviour
    on exit: &Statechart.MachineTest.print_notice/1
    state :red, do: :NEXT >>> :green
    state :yellow, do: :NEXT >>> :red
    state :green, do: :NEXT >>> :yellow
  end

  defmodule TrafficLight do
    statechart default: :off do
      state :off, do: :TOGGLE_POWER >>> :on
      # LATER replace subchart with chart that takes a partial: ModuleName option
      subchart :on, LightCycle, do: :TOGGLE_POWER >>> :off
    end

    # CONVENIENCE FUNCTIONS FOR TESTS
    def at(:off), do: new()
    def at(:red), do: new() |> Statechart.trigger(:TOGGLE_POWER)
    def at(:green), do: at(:red) |> Statechart.trigger(:NEXT)
    def at(:yellow), do: at(:green) |> Statechart.trigger(:NEXT)
  end

  # subchart module: LightCycle, default: :red do
  #   on exit: fn -> IO.puts("Exiting the light cycle") end
  #   state :green, do: :NEXT >>> :yellow
  #   state :yellow, do: :NEXT >>> :red
  #   state :red, do: :NEXT >>> :green
  # end

  # statechart module: TrafficLight, default: on do
  #   state :off, do: :TOGGLE_POWER >>> :on
  #   chart :on, subchart: LightCycle, do: :TOGGLE_POWER >>> :off
  #   # subchart :on, LightCycle, do: :TOGGLE_POWER >>> :off
  # end

  statechart module: MyStatechart, default: :on do
    state :on do
      :TOGGLE >>> :off
    end

    state :off do
      :TOGGLE >>> :on
    end
  end

  defmodule Sample do
    use Statechart

    statechart default: :d do
      state :a do
        state :b do
          :GOTO_G >>> :g

          state :c do
            state :d do
            end
          end
        end
      end

      state :e do
        state :f do
          state :g do
          end
        end
      end
    end
  end

  #####################################
  # CONSTRUCTORS
  #####################################

  describe "MyStatechart.machine/0" do
    test "returns a `Statechart.Machine.t`" do
      assert %Machine{} = MyStatechart.new()
    end
  end

  #####################################
  # REDUCERS
  #####################################

  describe "Statechart.Machine.transition/1" do
    test "throws when passed anything but a Machine struct"
    test "returns an `t:module()` otherwise"
    test "the returned module contains __statechart_build__/0 function"
  end

  #####################################
  # CONVERTERS
  #####################################

  describe "Statechart.Machine.state/1" do
    test "throws when passed anything but a Machine struct"
    test "returns an `t:atom()` otherwise"
  end

  describe "Statechart.Machine.statechart_module/1" do
    test "throws when passed anything but a Machine struct"
    test "returns an `t:module()` otherwise"
    test "the returned module contains __statechart_build__/0 function"
  end

  describe "transition/3" do
    defmodule SimpleToggle do
      use Statechart

      statechart default: :on do
        :GLOBAL_TURN_ON >>> :on
        :GLOBAL_TURN_OFF >>> :off

        state :on do
          :TOGGLE >>> :off
          :LOCAL_TURN_OFF >>> :off
        end

        state :off do
          :TOGGLE >>> :on
          :LOCAL_TURN_ON >>> :on
        end
      end
    end

    test "a transition registered directly on current node allows a transition" do
      assert [:off] == SimpleToggle.new() |> Statechart.trigger(:TOGGLE) |> Statechart.states()
    end

    # LATER log messages about non-existent events
    test "a non-existent event does not change the state" do
      toggle = SimpleToggle.new()

      # LATER test that calling Statechart macros outside of a statechart def (i.e. here) raises a StatechartError
      assert Statechart.states(toggle) ==
               Statechart.trigger(toggle, :NONEXISTENT_EVENT) |> Statechart.states()
    end

    test "a non-existent event causes the machine to know there was an error" do
      toggle = SimpleToggle.new()

      assert :error ==
               toggle |> Statechart.trigger(:NONEXISTENT_EVENT) |> Statechart.last_event_status()
    end

    test "a transition that doesn't apply to current returns an error tuple" do
      toggle = SimpleToggle.new()
      toggle_after_non_local_event = Statechart.trigger(toggle, :LOCAL_TURN_ON)
      assert [:on] == Statechart.states(toggle_after_non_local_event)
      assert :error == Statechart.last_event_status(toggle_after_non_local_event)
    end

    defp assert_state(machine, expected_state) do
      assert Statechart.in_state?(machine, expected_state)
    end

    test "a transition registered earlier in a node's path still allows an event" do
      on_toggle = SimpleToggle.new()
      off_toggle = Statechart.trigger(on_toggle, :TOGGLE)
      on_toggle |> Statechart.trigger(:GLOBAL_TURN_ON) |> assert_state(:on)
      on_toggle |> Statechart.trigger(:GLOBAL_TURN_OFF) |> assert_state(:off)
      off_toggle |> Statechart.trigger(:GLOBAL_TURN_OFF) |> assert_state(:off)
      off_toggle |> Statechart.trigger(:GLOBAL_TURN_ON) |> assert_state(:on)
    end
  end

  describe "defaults" do
    defmodule DefaultsTest do
      use Statechart

      # LATER the no resolved root node needs better error message.
      # Maybe tell user the last node it resolved to, but that that node has no default
      statechart default: :branch_with_default do
        :GOTO_BRANCH_WITH_DEFAULT >>> :branch_with_default
        :GOTO_BRANCH_NO_DEFAULT_BUT_NO_RESOLUTION >>> :branch_with_default_but_no_resolution

        # LATER this should actually fail at compile time
        state :branch_with_default_but_no_resolution, default: :branch_no_default do
          state :branch_no_default do
            state :a
          end
        end

        state :branch_with_default, default: :b do
          state :b
        end
      end
    end

    test "will cause travel to a default leaf node" do
      DefaultsTest.new()
      |> Statechart.trigger(:GOTO_BRANCH_WITH_DEFAULT)
      |> assert_state(:b)
    end
  end

  describe "on_exit and on_exit" do
    test "for a subchart root having actions declared at both the subchart and parent levels" do
      defmodule SubchartRootActionsBothLocalAndFromParent do
        use Statechart

        def action_entering_foo(_context), do: IO.puts("action declared by parent!")
        def action_entering_subchart(_context), do: IO.puts("action declared by subchart!")

        defmodule Subchart do
          use Statechart

          statechart do
            on enter: &SubchartRootActionsBothLocalAndFromParent.action_entering_subchart/1
          end
        end

        statechart default: :bar do
          :GOTO_FOO >>> :foo

          subchart :foo, Subchart do
            on enter: &__MODULE__.action_entering_foo/1
          end

          state :bar
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn ->
          SubchartRootActionsBothLocalAndFromParent.new() |> Statechart.trigger(:GOTO_FOO)
        end)

      assert captured_io =~ "declared by subchart!"
      assert captured_io =~ "declared by parent!"
    end

    test "actions registered on a subchart's root persist after being inserted into a parent chart" do
      defmodule SubchartRootHasActions do
        use Statechart

        def action_entering_subchart(_context), do: IO.puts("entering subchart!")

        defmodule Subchart do
          use Statechart

          statechart do
            on enter: &SubchartRootHasActions.action_entering_subchart/1
          end
        end

        statechart default: :bar do
          :GOTO_FOO >>> :foo
          subchart :foo, Subchart
          state :bar
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn ->
          SubchartRootHasActions.new() |> Statechart.trigger(:GOTO_FOO)
        end)

      assert captured_io =~ "entering subchart!"
    end

    test "on-exit & -enter actions fire" do
      defmodule OnExitEnterTest do
        use Statechart

        def action_put_a(_context), do: IO.puts("put a")
        def action_put_b(_context), do: IO.puts("put b")

        statechart default: :a do
          :GOTO_B >>> :b

          state :a do
            on exit: &__MODULE__.action_put_a/1
          end

          state :b do
            on enter: &__MODULE__.action_put_b/1
          end
        end
      end

      captured_io =
        ExUnit.CaptureIO.capture_io(fn -> OnExitEnterTest.new() |> Statechart.trigger(:GOTO_B) end)

      assert captured_io =~ "put a"
      assert captured_io =~ "put b"
    end
  end

  describe "states/1" do
    for {leaf_state, states} <- [
          off: [:off],
          red: [:on, :red],
          yellow: [:on, :yellow],
          green: [:on, :green]
        ] do
      test "returns #{inspect(states)} when in #{inspect(leaf_state)} state" do
        assert unquote(states) == unquote(leaf_state) |> TrafficLight.at() |> Statechart.states()
      end
    end
  end
end
