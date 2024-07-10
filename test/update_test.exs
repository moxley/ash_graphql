defmodule AshGraphql.UpdateTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:ash_graphql, AshGraphql.Test.Domain)

      try do
        AshGraphql.TestHelpers.stop_ets()
      rescue
        _ ->
          :ok
      end
    end)
  end

  test "an update works" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar")
      |> Ash.create!()

    resp =
      """
      mutation UpdatePost($id: ID!, $input: UpdatePostInput) {
        updatePost(id: $id, input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "text" => "barbuz"
          }
        }
      )

    assert {:ok, %{data: %{"updatePost" => %{"errors" => [], "result" => %{"text" => "barbuz"}}}}} =
             resp
  end

  test "an update with a managed relationship works" do
    resp =
      """
      mutation CreatePostWithComments($input: CreatePostWithCommentsInput) {
        createPostWithComments(input: $input) {
          result{
            id
            text
            comments(sort:{field:TEXT}){
              id
              text
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "input" => %{
            "text" => "foobar",
            "comments" => [
              %{"text" => "foobar"},
              %{"text" => "barfoo"}
            ]
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "createPostWithComments" => %{
                 "result" => %{
                   "id" => post_id,
                   "text" => "foobar",
                   "comments" => [
                     %{"id" => comment_id, "text" => "barfoo"},
                     %{"text" => "foobar"}
                   ]
                 }
               }
             }
           } = result

    resp =
      """
      mutation UpdatePostWithComments($id: ID!, $input: UpdatePostWithCommentsInput) {
        updatePostWithComments(id: $id, input: $input) {
          result{
            comments(sort:{field:TEXT}){
              id
              text
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post_id,
          "input" => %{
            "comments" => [
              %{"text" => "barfoonew", "id" => comment_id}
            ]
          }
        }
      )

    assert {:ok, result} = resp

    refute Map.has_key?(result, :errors)

    assert %{
             data: %{
               "updatePostWithComments" => %{
                 "result" => %{
                   "comments" => [%{"id" => ^comment_id, "text" => "barfoonew"}]
                 }
               }
             }
           } = result
  end

  test "an update with a configured read action and no identity works" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

    resp =
      """
      mutation UpdateBestPost($input: UpdateBestPostInput) {
        updateBestPost(input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "text" => "barbuz"
          }
        }
      )

    assert {:ok,
            %{data: %{"updateBestPost" => %{"errors" => [], "result" => %{"text" => "barbuz"}}}}} =
             resp
  end

  test "an update with a configured read action and no identity works with an argument the same name as an attribute" do
    AshGraphql.Test.Post
    |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
    |> Ash.create!()

    resp =
      """
      mutation UpdateBestPostArg($best: Boolean!, $input: UpdateBestPostArgInput) {
        updateBestPostArg(best: $best, input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "best" => true,
          "input" => %{
            "text" => "barbuz"
          }
        }
      )

    assert {:ok,
            %{
              data: %{"updateBestPostArg" => %{"errors" => [], "result" => %{"text" => "barbuz"}}}
            }} = resp
  end

  test "arguments are threaded properly" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

    resp =
      """
      mutation UpdatePostConfirm($input: UpdatePostConfirmInput, $id: ID!) {
        updatePostConfirm(input: $input, id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar2"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "updatePostConfirm" => %{"result" => nil, "errors" => [%{"message" => message}]}
             }
           } = result

    assert message =~ "confirmation did not match value"
  end

  test "root level error" do
    Application.put_env(:ash_graphql, AshGraphql.Test.Domain,
      graphql: [show_raised_errors?: true, root_level_errors?: true]
    )

    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar", best: true)
      |> Ash.create!()

    resp =
      """
      mutation UpdatePostConfirm($input: UpdatePostConfirmInput, $id: ID!) {
        updatePostConfirm(input: $input, id: $id) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "text" => "foobar",
            "confirmation" => "foobar2"
          }
        }
      )

    assert {:ok, result} = resp

    assert %{errors: [%{message: message}]} = result

    assert message =~ "confirmation did not match value"
  end

  test "referencing a hidden input is not allowed" do
    post =
      AshGraphql.Test.Post
      |> Ash.Changeset.for_create(:create, text: "foobar")
      |> Ash.create!()

    resp =
      """
      mutation UpdatePostWithHiddenInput($id: ID!, $input: UpdatePostWithHiddenInputInput) {
        updatePostWithHiddenInput(id: $id, input: $input) {
          result{
            text
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "id" => post.id,
          "input" => %{
            "score" => 10
          }
        }
      )

    assert {
             :ok,
             %{
               errors: [
                 %{
                   message:
                     "Argument \"input\" has invalid value $input.\nIn field \"score\": Unknown field."
                 }
               ]
             }
           } =
             resp
  end

  test "an update with a configured read action and no identity works in resource with simple data layer" do
    channel =
      AshGraphql.Test.Channel
      |> Ash.Changeset.for_create(:create, name: "test channel 1")
      |> Ash.create!()

    resp =
      """
      mutation UpdateChannel($channelId: ID!, $input: UpdateChannelInput!) {
        updateChannel(channelId: $channelId, input: $input) {
          result{
            channel {
              name
            }
          }
          errors{
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        variables: %{
          "channelId" => channel.id,
          "input" => %{"name" => "test channel 2"}
        }
      )

    assert {:ok, result} = resp

    assert %{
             data: %{
               "updateChannel" => %{"result" => %{"channel" => %{"name" => "test channel 2"}}}
             }
           } =
             result
  end

  test "updateCurrentUser" do
    user = AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create, %{name: "Name"})
      |> Ash.create!(authorize?: false)

    resp =
      """
      mutation UpdateCurrentUser {
        updateCurrentUser {
          result {
            name
          }
          errors {
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema,
        context: %{
          actor: user
        }
      )

      # Logs the following:
      #
      # 13:38:11.914 [warning] `fa343d97-883c-4734-9696-60e52b4bcfd4`: AshGraphql.Error not implemented for error:

      # ** (Ash.Error.Invalid.NoMatchingBulkStrategy) AshGraphql.Test.User.update had no matching bulk strategy that could be used.

      # Requested strategies: [:atomic]

      # Could not use `:stream`: could not stream the query
      # Could not use `:atomic_batches`: Not in requested strategies
      # Could not use `:atomic`: cannot atomically update a query if it has `before_action` or `after_action` hooks



      # Non stream reason:

      # Action AshGraphql.Test.User.current_user does not support streaming with one of [:keyset].

      # There are two ways to handle this.

      # 1.) Use the `allow_stream_with` or `stream_with` options to control what strategies are allowed.
      # 2.) Enable the respective required pagination type on the action current_user, for example:

      #     # allow keyset
      #     pagination keyset?: true, required?: false

      #     # allow offset
      #     pagination offset?: true, required?: false

      #     # allow both
      #     pagination offset?: true, keyset?: true, required?: false



      #     (elixir 1.16.0) lib/process.ex:860: Process.info/2
      #     (ash 3.0.16) lib/ash/error/invalid/no_matching_bulk_strategy.ex:5: Ash.Error.Invalid.NoMatchingBulkStrategy.exception/1
      #     (ash 3.0.16) lib/ash/actions/update/bulk.ex:104: Ash.Actions.Update.Bulk.run/6
      #     (ash 3.0.16) lib/ash/actions/update/bulk.ex:955: anonymous fn/7 in Ash.Actions.Update.Bulk.do_atomic_batches/6
      #     (elixir 1.16.0) lib/stream.ex:613: anonymous fn/4 in Stream.map/2
      #     (elixir 1.16.0) lib/stream.ex:1816: anonymous fn/3 in Enumerable.Stream.reduce/3
      #     (elixir 1.16.0) lib/stream.ex:289: Stream.after_chunk_while/2
      #     (elixir 1.16.0) lib/stream.ex:1845: Enumerable.Stream.do_done/2
      #     (elixir 1.16.0) lib/stream.ex:1828: Enumerable.Stream.do_each/4
      #     (elixir 1.16.0) lib/stream.ex:943: Stream.do_transform/5
      #     (elixir 1.16.0) lib/enum.ex:4399: Enum.reverse/1
      #     (elixir 1.16.0) lib/enum.ex:3728: Enum.to_list/1
      #     (ash 3.0.16) lib/ash/actions/update/bulk.ex:1070: Ash.Actions.Update.Bulk.run_batches/3
      #     (ash 3.0.16) lib/ash/actions/update/bulk.ex:386: Ash.Actions.Update.Bulk.run/6
      #     (ash_graphql 1.2.0) lib/graphql/resolver.ex:1236: AshGraphql.Graphql.Resolver.mutate/2
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:234: Absinthe.Phase.Document.Execution.Resolution.reduce_resolution/1
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:189: Absinthe.Phase.Document.Execution.Resolution.do_resolve_field/3
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:174: Absinthe.Phase.Document.Execution.Resolution.do_resolve_fields/6
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:145: Absinthe.Phase.Document.Execution.Resolution.resolve_fields/4
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:88: Absinthe.Phase.Document.Execution.Resolution.walk_result/5

    # Fails with actual value:
    # {:ok, %{data: %{"updateCurrentUser" => %{"errors" => [%{"message" => "something went wrong. Unique error id: `fa343d97-883c-4734-9696-60e52b4bcfd4`"}], "result" => nil}}}}
    assert {:ok,
            %{
              data: %{
                "updateCurrentUser" => %{"errors" => [], "result" => %{"name" => "Name"}}
              }
            }} = resp
  end
end
