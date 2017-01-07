use Mix.Config

config :npc,
  ecto_repos: [Helix.NPC.Repo]
config :npc, Helix.NPC.Repo,
  size: 4,
  adapter: Ecto.Adapters.Postgres,
  database: "npc_service",
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  extensions: [
    {Postgrex.Extensions.Network, nil}
  ]

import_config "#{Mix.env}.exs"