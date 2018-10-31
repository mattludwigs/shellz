defmodule Shellz do
  defmodule Evaluator do
    def init(command, server, leader, _opts) do
      old_leader = Process.group_leader
      Process.group_leader(self(), leader)

      command == :ack && :proc_lib.init_ack(self())

      state = nil

      try do
        loop(server, state)
      after
        Process.group_leader(self(), old_leader)
      end
    end

    def loop(server, state) do
      receive do
        _ ->
          IO.puts("Message received")
          loop(server, state)
      end
    end
  end

  defmodule Server do
    def start(_, {m, f, a}) do
      Process.flag(:trap_exit, true)
      {pid, ref} = spawn_monitor(m, f, a)
      start_loop(pid, ref)
    end

    def start_loop(pid, ref) do
      receive do
        {:DOWN, ^ref, :process, ^pid, :normal} ->
          run([])
        {:DOWN, ^ref, :process, ^pid, other} ->
          IO.puts("#{__MODULE__} failed to start due to reason: #{inspect other}")
      end
    end

    def start_evaluator(_) do
      self_pid = self()
      self_leader = Process.group_leader
      evaluator = :proc_lib.start(Shellz.Evaluator, :init, [:ack, self_pid, self_leader, []])
      evaluator
    end

    def run(_) do
      IO.puts """
      HELLO!!!!!!
      """

      evaluator = start_evaluator(nil)
      state = %{counter: 1}

      loop(state, evaluator, Process.monitor(evaluator))
    end


    def loop(state, evaluator, evaluator_ref) do
      self_pid = self()
      input = spawn(fn -> io_get(self_pid) end)
      wait_for_input(state, evaluator, evaluator_ref, input)
    end

    def io_get(pid) do
      prompt = "shelling it [up]> "
      send(pid, {:input, self(), IO.gets(:stdio, prompt)})
    end

    def wait_for_input(state, evaluator, evaluator_ref, input) do
      receive do
        {:input, ^input, command} when is_binary(command) ->
          send(evaluator, {:eval, self(), command, state})
          wait_for_eval(state, evaluator, evaluator_ref)
      end
    end

    def wait_for_eval(state, evaluator, evaluator_ref) do
      receive do
        {:evaled, ^evaluator, new_state} ->
          loop(new_state, evaluator, evaluator_ref)
      end
    end
  end

  def start(opts \\ [], mfa \\ {Shellz, :dont_display_result, []}) do
    spawn(fn ->
      case :init.notify_when_started(self()) do
        :started -> :ok
        _        -> :init.wait_until_started()
      end
    end)

    :io.setopts(Process.group_leader, binary: true, encoding: :unicode)

    Shellz.Server.start(opts, mfa)
  end

  def dont_display_result, do: :"do not show this result in output"

end

defmodule :stuff do
  defdelegate start, to: Shellz
end
