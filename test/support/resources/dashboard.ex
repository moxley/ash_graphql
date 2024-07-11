defmodule AshGraphql.Test.Dashboard do
  @moduledoc false

  use Ash.Resource,
    domain: AshGraphql.Test.Domain,
    extensions: [AshGraphql.Resource]

  graphql do
    type :dashboard

    queries do
      get :get_dashboard, :read do
        identity false
      end
    end
  end

  actions do
    default_accept :*

    read :read do
      get? true
      primary? true

      prepare fn query, context ->
        Ash.Query.before_action(query, fn query ->
          Ash.DataLayer.Simple.set_data(query, [
            %__MODULE__{
              id: Ash.UUID.generate(),
              name: "Test Name",
              group_id: 1
            }
          ])
        end)
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
    attribute :group_id, :integer
  end

  calculations do
    calculate :users_count, :integer, AshGraphql.Test.UsersCountCalculation, public?: true
  end
end
