defmodule Expression.V2.EvalCompatTest do
  use ExUnit.Case, async: true
  alias Expression.V2
  alias Expression.V2.Parser
  alias Expression.V2.Compat
  alias Expression.Eval

  test "substitution" do
    assert "bar" == Compat.evaluate_as_string!("@foo", %{"foo" => "bar"})
  end

  test "substitutions in substitutions" do
    assert "string with quotes \" inside" ==
             Compat.evaluate_block!(~S("string with quotes \" inside"))

    # I'm not sure if this is desirable behaviour to begin with
    #
    # # credo:disable-for-lines:2 Credo.Check.Readability.StringSigils
    # assert true ==
    #          Compat.evaluate_block!(
    #            "block.response = \"@@IF(cursor + 1 < total_items, \\\"Next article ➡️\\\", \\\"⏮ First article\\\")\"",
    #            %{
    #              "block" => %{
    #                "response" =>
    #                  "@IF(cursor + 1 < total_items, \"Next article ➡️\", \"⏮ First article\")"
    #              },
    #              "cursor" => "1",
    #              "total_items" => "10"
    #            }
    #          )

    assert "Your application was successful" ==
             Compat.evaluate_as_string!(
               ~s|Your application @if(conditional, "was @confirm", "was @deny")|,
               %{
                 "conditional" => true,
                 "confirm" => "successful",
                 "deny" => "unsuccessful"
               }
             )

    assert "Your application was unsuccessful" ==
             Compat.evaluate_as_string!(
               ~s|Your application @if(conditional, "was @confirm", "was @deny")|,
               %{
                 "conditional" => false,
                 "confirm" => "successful",
                 "deny" => "unsuccessful"
               }
             )
  end

  test "attributes on substitutions" do
    assert "baz" == Compat.evaluate_as_string!("@foo.bar", %{"foo" => %{"bar" => "baz"}})
  end

  test "attributes with literals" do
    assert "value" ==
             Compat.evaluate_as_string!("@foo.bar.123.baz", %{
               "foo" => %{
                 "bar" => %{
                   "123" => %{
                     "baz" => "value"
                   }
                 }
               }
             })
  end

  test "functions" do
    {:ok, ast, "", _, _, _} = Parser.parse(~s[@has_any_word("The Quick Brown Fox", "red fox")])

    assert [%{"__value__" => true, "match" => "Fox"}] == V2.eval_ast(ast)
  end

  test "if" do
    {:ok, ast, "", _, _, _} =
      Parser.parse("@if(image_response.status == 200,\nimage_response.body.id,\nfalse)")

    assert [false] ==
             V2.eval_ast(
               ast,
               V2.Context.new(%{
                 "image_response" => %{"status" => 500, "body" => "Internal Server Error"}
               })
             )
  end

  describe "lambdas" do
    test "with map" do
      {:ok, ast, "", _, _, _} = Parser.parse("@map(foo, &([&1, 'Button']))")

      assert [[[1, "Button"], [2, "Button"], [3, "Button"]]] ==
               V2.eval_ast(ast, V2.Context.new(%{"foo" => [1, 2, 3]}))
    end

    test "with functions" do
      {:ok, ast, "", _, _, _} = Parser.parse("@map(1..3, &date(2022, 5, &1))")

      assert [
               [
                 ~D[2022-05-01],
                 ~D[2022-05-02],
                 ~D[2022-05-03]
               ]
             ] == V2.eval_ast(ast, V2.Context.new(%{}))
    end

    test "with arithmetic" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(map(foo, &([&1, 'Button'])))")

      assert [[[1, "Button"], [2, "Button"], [3, "Button"]]] ==
               V2.eval_ast(ast, V2.Context.new(%{"foo" => [1, 2, 3]}))
    end

    test "lambda with joins" do
      assert [["one", "Button one"], ["two", "Button two"], ["three", "Button three"]] ==
               Compat.evaluate!("@map(choices, &([&1, concatenate('Button ', &1)]))", %{
                 "choices" => ["one", "two", "three"]
               })
    end
  end

  test "email addresses" do
    assert "email info@one.two.three.four.five.six for more information" ==
             Compat.evaluate_as_string!(
               "email info@one.two.three.four.five.six for more information",
               %{}
             )
  end

  test "attributes on functions" do
    assert "Fox" ==
             Compat.evaluate_as_string!(
               ~s[@has_any_word("The Quick Brown Fox", "red fox").match],
               %{}
             )
  end

  describe "lists" do
    test "with integer indices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1]")

      assert [1] == V2.eval_ast(ast, V2.Context.new(%{"foo" => [0, 1, 2]}))
    end

    test "with binary keys" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo['a']")

      assert [1] == V2.eval_ast(ast, V2.Context.new(%{"foo" => %{"a" => 1}}))
    end

    test "with binary keys as variables" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[bar]")

      assert [1] == V2.eval_ast(ast, V2.Context.new(%{"foo" => %{"a" => 1}, "bar" => "a"}))
    end

    test "with binary keys as variables and strings" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[bar]['baz']")

      assert [1] ==
               V2.eval_ast(ast, V2.Context.new(%{"foo" => %{"a" => %{"baz" => 1}}, "bar" => "a"}))
    end

    test "with function" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[day(now())]")
      today = DateTime.utc_now().day
      assert [today] == V2.eval_ast(ast, V2.Context.new(%{"foo" => Enum.to_list(0..31)}))
    end

    test "with range slices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1..3]")
      assert [[1, 2, 3]] == V2.eval_ast(ast, V2.Context.new(%{"foo" => Enum.to_list(0..31)}))
    end
  end

  test "arithmetic" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 1)")
    assert [2] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 2 * 3)")
    assert [7] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) * 3)")
    assert [9] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) / 3)")
    assert [1.0] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(6 / 2 + 1)")
    assert [4.0] == V2.eval_ast(ast, V2.Context.new(%{}))
  end

  test "arithmetic with decimals" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1.5 + 1.5)")
    assert [3.0] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(1.5 + 2.5 * 3.5)")
    assert [10.25] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@((1.5 + 2.5) * 3.5)")
    assert [14.00] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@((1.5 + 2.5) / 3.5)")
    assert [1.1428571428571428] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(6.8 / 2.0 + 1.5)")
    assert [4.9] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(2.002 * 0.05)")
    assert [0.10010] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 > 0.5)")
    assert [true] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 >= 2.0)")
    assert [true] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 < 0.5)")
    assert [false] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 <= 2.0)")
    assert [true] == V2.eval_ast(ast, V2.Context.new(%{}))
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 == 2.0)")
    assert [true] == V2.eval_ast(ast, V2.Context.new(%{}))
  end

  test "text" do
    assert "hello Bob" ==
             Compat.evaluate_as_string!("hello @contact.name", %{
               "contact" => %{"name" => "Bob"}
             })
  end
end
