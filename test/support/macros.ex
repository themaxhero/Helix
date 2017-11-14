defmodule Helix.Test.Macros do

  defmacro assert_map(a, b, skip: skip) do
    skip = is_list(skip) && skip || [skip]
    quote bind_quoted: binding() do
      assert Map.drop(a, skip) == Map.drop(b, skip)
    end
  end

  defmacro timeout(severity \\ quote(do: _)) do
    env = System.get_env("HELIX_TEST_ENV")
    env_multiplier = get_env_multiplier(env)
    timeout_severity = timeout_by_severity(severity)

    quote do
      unquote(timeout_severity) * unquote(env_multiplier)
    end
  end

  defmacro sleep(duration) do
    env = System.get_env("HELIX_TEST_ENV")
    env_multiplier = get_env_multiplier(env)
    sleep_duration = duration * env_multiplier

    quote do
      :timer.sleep(unquote(sleep_duration))
    end
  end

  defp get_env_multiplier("travis"),
    do: 4
  defp get_env_multiplier("jenkins"),
    do: 2
  defp get_env_multiplier(_),
    do: 1

  defp timeout_by_severity(:slow),
    do: 200
  defp timeout_by_severity(:fast),
    do: 50
  defp timeout_by_severity(_),
    do: 100
end
