defmodule Statechart.Experiment.FunctionsAcc do
  @spec start() :: pid
  def start do
    case Agent.start_link(fn -> [] end) do
      {:ok, pid} -> pid
      :error -> :error
    end
  end

  @spec push(pid, term) :: pid
  def push(acc, fun) do
    Agent.update(acc, &[fun | &1])
    acc
  end

  defp get(acc), do: Agent.get(acc, &Enum.reverse/1)

  @spec get_and_stop(pid) :: [(term -> term)]
  def get_and_stop(acc) do
    val = get(acc)
    Agent.stop(acc)
    val
  end
end

defmodule Statechart.Experiment.Macros1 do
  defmacro build_it do
    quote do
      alias Statechart.Experiment.FunctionsAcc
      pid = FunctionsAcc.start()

      pid
      |> FunctionsAcc.push(fn x -> x + 3 end)
      |> FunctionsAcc.push(&(&1 * 2))
      |> FunctionsAcc.push(&List.wrap/1)

      FunctionsAcc.get_and_stop(pid)
    end
  end

  defmacro do_all_the_things() do
    quote do
      def functions do
        build_it()
      end
    end
  end
end

defmodule Statechart.Experiment.Macros2 do
  defmacro start(do: block) do
    inner_val_ast =
      quote do
        alias Statechart.Experiment.FunctionsAcc
        var!(pid) = FunctionsAcc.start()
        unquote(block)

        FunctionsAcc.get_and_stop(var!(pid))
        |> IO.inspect(label: "executed at compile- or run-time?")
      end

    quote do
      def functions do
        # NOTE unfortunately, the above AST runs each time functions/0 is called.
        # That is definitely not what I want.
        # I tried using Macro.escape, but that just makes functions/0 return
        # an ugly AST.
        # Next I'll try using a before_compile callback.
        unquote(inner_val_ast)
      end

      def result do
        Enum.reduce(functions(), 1, & &1.(&2))
      end
    end
  end
end

defmodule Statechart.Experiment.BeforeCompile.Macros do
  alias Statechart.Experiment.FunctionsAcc

  defmacro start() do
    quote do
      alias Statechart.Experiment.FunctionsAcc
      @acc_pid FunctionsAcc.start()
      @before_compile unquote(__MODULE__)

      def result do
        Enum.reduce(functions(), 1, & &1.(&2))
      end
    end
  end

  defmacro __before_compile__(env) do
    acc_pid = Module.get_attribute(env.module, :acc_pid)

    functions =
      FunctionsAcc.get_and_stop(acc_pid)
      |> IO.inspect(label: "executed at compile- or run-time?")

    quote do
      def functions do
        unquote(functions)
      end
    end
  end
end

defmodule Statechart.Experiment.BeforeCompileFull.Macros do
  alias Statechart.Experiment.FunctionsAcc

  defmacro start(do: block) do
    quote do
      alias Statechart.Experiment.FunctionsAcc
      @acc_pid FunctionsAcc.start()
      @before_compile unquote(__MODULE__)
      unquote(block)

      def result do
        Enum.reduce(functions(), 1, & &1.(&2))
      end
    end
  end

  defmacro push_function(fun) do
    IO.inspect(fun)

    quote do
      FunctionsAcc.push(@acc_pid, unquote(Macro.escape(fun)))
    end
  end

  defmacro __before_compile__(env) do
    acc_pid = Module.get_attribute(env.module, :acc_pid)

    functions =
      FunctionsAcc.get_and_stop(acc_pid)
      |> IO.inspect(label: "executed at compile- or run-time?")

    quote do
      def functions do
        unquote(functions)
      end
    end
  end
end
