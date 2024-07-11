defmodule AshGraphql.Test.UsersCountCalculation do
  @moduledoc false
  use Ash.Resource.Calculation

  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      # In a real application, there would be a database query here to get the count of users.
      # The database query depends on record.group_id.
      # Instead of being an integer as expected, it is #Ash.NotLoaded<:attribute, field: :group_id>
      is_integer(record.group_id) || raise "group_id must be an integer"
      20
    end)
  end
end
