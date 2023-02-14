# AshGraphql

Example application from the Ash Framework Getting Started guide:
https://ash-hq.org/docs/guides/ash/latest/tutorials/get-started

## Usage

You must have Elixir an PostgreSQL installed. PostgreSQL must have a `postgres` user that
can be used to log in to `psql` with the command `psql -U postgres`, with either the `postgres`
password, or no password.

1. Check out this repo
2. Get Elixir dependencies: `mix deps.get`
3. Create the development database: `mix do ecto.create, ecto.migrate`
4. Run the server: `iex -S mix`

You can access to the GraphQL query interface at <http://localhost:8081/playground>.
