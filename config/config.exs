# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :arevel,
  ecto_repos: [Arevel.Repo]

# Configures the endpoint
config :arevel, ArevelWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "DqSWB2WiPqU8PT3fhWkiedv4J7fBQfjgMq+4zOpneSmnROtKObLA1sCqClsTUT1j",
  render_errors: [view: ArevelWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Arevel.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "j+AE0L6RX+89b5VJoEUy9c96t4m3jSd9"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :phoenix, template_engines: [leex: Phoenix.LiveView.Engine]


# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
