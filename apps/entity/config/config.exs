use Mix.Config

config :entity,
  ecto_repos: [HELM.Entity.Repo]

config :entity, HELM.Entity.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "entity_service",
  username: System.get_env("HELIX_DB_USER"),
  password: System.get_env("HELIX_DB_PASS"),
  hostname: System.get_env("HELIX_DB_HOST")