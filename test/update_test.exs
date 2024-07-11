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

  test "authenticateWithToken" do
    _user = AshGraphql.Test.User
      |> Ash.Changeset.for_create(:create, %{name: "Name"})
      |> Ash.create!(authorize?: false)

    resp =
      """
      mutation AuthenticateWithToken($token: String!) {
        authenticateWithToken(token: $token) {
          result {
            name
          }
          errors {
            message
          }
        }
      }
      """
      |> Absinthe.run(AshGraphql.Test.Schema, variables: %{"token" => "invalid-token"})

      # Emits the following error
      #
      # 20:00:23.645 [error] 0ec3c77a-5d11-4f8d-9e27-416c39148251: Exception raised while resolving query.

      # ** (Ash.Error.Invalid) Invalid Error

      # * test error
      #   (ash 3.1.2) /Users/moxley/work/ash_graphql/deps/splode/lib/splode.ex:277: Ash.Error.to_error/2
      #   (elixir 1.16.0) lib/enum.ex:1700: Enum."-map/2-lists^map/1-1-"/2
      #   (ash 3.1.2) /Users/moxley/work/ash_graphql/deps/splode/lib/splode.ex:222: Ash.Error.choose_error/1
      #   (ash 3.1.2) /Users/moxley/work/ash_graphql/deps/splode/lib/splode.ex:211: Ash.Error.to_class/2
      #   (ash 3.1.2) lib/ash/error/error.ex:66: Ash.Error.to_error_class/2
      #   (ash 3.1.2) lib/ash/actions/read/read.ex:320: Ash.Actions.Read.do_run/3
      #   (ash 3.1.2) lib/ash/actions/read/read.ex:66: anonymous fn/3 in Ash.Actions.Read.run/3
      #   (ash 3.1.2) lib/ash/actions/read/read.ex:65: Ash.Actions.Read.run/3
      #   (ash 3.1.2) lib/ash.ex:1844: Ash.read/2
      #   (ash 3.1.2) lib/ash.ex:1803: Ash.read!/2
      #   (ash 3.1.2) lib/ash/actions/read/stream.ex:141: anonymous fn/5 in Ash.Actions.Read.Stream.stream_with_limit_offset/3
      #   (elixir 1.16.0) lib/stream.ex:1626: Stream.do_resource/5
      #   (elixir 1.16.0) lib/stream.ex:1828: Enumerable.Stream.do_each/4
      #   (elixir 1.16.0) lib/stream.ex:943: Stream.do_transform/5
      #   (elixir 1.16.0) lib/enum.ex:4399: Enum.reverse/1
      #   (elixir 1.16.0) lib/enum.ex:3728: Enum.to_list/1
      #   (ash 3.1.2) lib/ash/actions/update/bulk.ex:1148: Ash.Actions.Update.Bulk.run_batches/3

      #     (elixir 1.16.0) lib/process.ex:860: Process.info/2
      #     (ash 3.1.2) lib/ash/error/invalid.ex:3: Ash.Error.Invalid.exception/1
      #     (ash 3.1.2) /Users/moxley/work/ash_graphql/deps/splode/lib/splode.ex:211: Ash.Error.to_class/2
      #     (ash 3.1.2) lib/ash/error/error.ex:66: Ash.Error.to_error_class/2
      #     (ash 3.1.2) lib/ash/actions/read/read.ex:320: Ash.Actions.Read.do_run/3
      #     (ash 3.1.2) lib/ash/actions/read/read.ex:66: anonymous fn/3 in Ash.Actions.Read.run/3
      #     (ash 3.1.2) lib/ash/actions/read/read.ex:65: Ash.Actions.Read.run/3
      #     (ash 3.1.2) lib/ash.ex:1844: Ash.read/2
      #     (ash 3.1.2) lib/ash.ex:1803: Ash.read!/2
      #     (ash 3.1.2) lib/ash/actions/read/stream.ex:141: anonymous fn/5 in Ash.Actions.Read.Stream.stream_with_limit_offset/3
      #     (elixir 1.16.0) lib/stream.ex:1626: Stream.do_resource/5
      #     (elixir 1.16.0) lib/stream.ex:1828: Enumerable.Stream.do_each/4
      #     (elixir 1.16.0) lib/stream.ex:943: Stream.do_transform/5
      #     (elixir 1.16.0) lib/enum.ex:4399: Enum.reverse/1
      #     (elixir 1.16.0) lib/enum.ex:3728: Enum.to_list/1
      #     (ash 3.1.2) lib/ash/actions/update/bulk.ex:1148: Ash.Actions.Update.Bulk.run_batches/3
      #     (ash 3.1.2) lib/ash/actions/update/bulk.ex:415: Ash.Actions.Update.Bulk.run/6
      #     (ash_graphql 1.2.0) lib/graphql/resolver.ex:1236: AshGraphql.Graphql.Resolver.mutate/2
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:234: Absinthe.Phase.Document.Execution.Resolution.reduce_resolution/1
      #     (absinthe 1.7.6) lib/absinthe/phase/document/execution/resolution.ex:189: Absinthe.Phase.Document.Execution.Resolution.do_resolve_field/3

    assert {:ok,
            %{
              data: %{
                "authenticateWithToken" => %{"errors" => [], "result" => %{"name" => "Name"}}
              }
            }} = resp
  end
end
