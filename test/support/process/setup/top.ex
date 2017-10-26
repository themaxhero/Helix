defmodule Helix.Test.Process.Setup.TOP do

  alias Helix.Test.Process.Helper.TOP, as: TOPHelper
  alias Helix.Test.Network.Helper, as: NetworkHelper

  @internet_id NetworkHelper.internet_id()

  def fake_process(opts \\ []) do
    num_procs = Keyword.get(opts, :total, 1)
    network_id = Keyword.get(opts, :network_id, @internet_id)

    res_usage =
      TOPHelper.Resources.split_usage(
        opts[:total_resources], num_procs, network_id
      )

    1..num_procs
    |> Enum.map(fn _ ->
      gen_fake_process(opts, res_usage)
    end)
  end

  defp gen_fake_process(opts, res_usage) do
    priority = Keyword.get(opts, :priority, 3)
    state = Keyword.get(opts, :state, :running)

    network_id = Keyword.get(opts, :network_id, @internet_id)
    dynamic = Keyword.get(opts, :dynamic, [:cpu, :ram])

    static = TOPHelper.Resources.calculate_static(opts, res_usage)

    %{
      priority: priority,
      state: state,
      static: static,
      dynamic: dynamic,
      network_id: network_id
    }
  end
end
