defmodule Expression.EvalTest do
  use ExUnit.Case, async: true
  alias Expression.Eval
  alias Expression.Parser

  test "substitution" do
    assert "bar" == Expression.evaluate_as_string!("@foo", %{"foo" => "bar"})
  end

  test "substitutions in substitutions" do
    assert "string with quotes \" inside" ==
             Expression.evaluate_block!(~S("string with quotes \" inside"))

    # Note the escaping of the @IF here with an @
    # credo:disable-for-lines:2 Credo.Check.Readability.StringSigils
    assert true ==
             Expression.evaluate_block!(
               "block.response = \"@@IF(cursor + 1 < total_items, \\\"Next article ➡️\\\", \\\"⏮ First article\\\")\"",
               %{
                 "block" => %{
                   "response" =>
                     "@IF(cursor + 1 < total_items, \"Next article ➡️\", \"⏮ First article\")"
                 },
                 "cursor" => "1",
                 "total_items" => "10"
               }
             )

    assert "Your application was successful" ==
             Expression.evaluate_as_string!(
               ~s|Your application @if(conditional, "was @confirm", "was @deny")|,
               %{
                 "conditional" => true,
                 "confirm" => "successful",
                 "deny" => "unsuccessful"
               }
             )

    assert "Your application was unsuccessful" ==
             Expression.evaluate_as_string!(
               ~s|Your application @if(conditional, "was @confirm", "was @deny")|,
               %{
                 "conditional" => false,
                 "confirm" => "successful",
                 "deny" => "unsuccessful"
               }
             )

    assert "true" ==
             Expression.evaluate_as_string!(
               ~s|@or(answer == 1, has_all_words(answer, "red fox"))|,
               %{
                 "answer" => "1"
               }
             )
  end

  test "attributes on substitutions" do
    assert "baz" == Expression.evaluate_as_string!("@foo.bar", %{"foo" => %{"bar" => "baz"}})
  end

  test "attributes on things that cannot have attributes should return nil" do
    assert nil == Expression.evaluate_block!("foo.bar", %{"foo" => "not a map"})
  end

  test "attributes with literals" do
    assert "value" ==
             Expression.evaluate_as_string!("@foo.bar.123.baz", %{
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

    assert %{"__value__" => true, "match" => "Fox"} == Eval.eval!(ast, %{})

    {:ok, ast, "", _, _, _} = Parser.parse(~s[@or(1 == 1, has_all_words("Red Fox", "red fox"))])

    assert true == Eval.eval!(ast, %{})
  end

  test "concatenate with default values" do
    now = "2023-12-07T09:47:27.234912Z"

    ctx = %{
      "flow" => %{
        "date" => now,
        "time" => "09:30:00"
      }
    }

    {:ok, ast, "", _, _, _} =
      Parser.parse(~s|@datevalue(concatenate(datevalue(flow.date, "%Y-%m-%d"), "T", flow.time))|)

    assert ~U[2023-12-07 09:30:00.0Z] == Eval.eval!(ast, ctx)["datetime"]
    assert ~D[2023-12-07] == Eval.eval!(ast, ctx)["date"]
  end

  test "if" do
    {:ok, ast, "", _, _, _} =
      Parser.parse("@if(image_response.status == 200,\nimage_response.body.id,\nfalse)")

    assert false ==
             Eval.eval!(ast, %{
               "image_response" => %{"status" => 500, "body" => "Internal Server Error"}
             })
  end

  describe "lambdas" do
    test "with map" do
      {:ok, ast, "", _, _, _} = Parser.parse("@map(foo, &([&1,'Button']))")

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] ==
               Eval.eval!(ast, %{"foo" => [1, 2, 3]})
    end

    test "with functions" do
      {:ok, ast, "", _, _, _} = Parser.parse("@map(1..3, &date(2022, 5, &1))")

      assert [
               ~D[2022-05-01],
               ~D[2022-05-02],
               ~D[2022-05-03]
             ] == Eval.eval!(ast, %{})
    end

    test "with arithmetic" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(map(foo, &([&1, 'Button'])))")

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] ==
               Eval.eval!(ast, %{"foo" => [1, 2, 3]})
    end

    test "lambda with joins" do
      assert [["one", "Button one"], ["two", "Button two"], ["three", "Button three"]] ==
               Expression.evaluate!("@map(choices, &([&1, 'Button ' & &1]))", %{
                 "choices" => ["one", "two", "three"]
               })
    end
  end

  test "email addresses" do
    assert "email info@one.two.three.four.five.six for more information" ==
             Expression.evaluate_as_string!(
               "email info@one.two.three.four.five.six for more information",
               %{}
             )
  end

  test "attributes on functions" do
    assert "Fox" ==
             Expression.evaluate_as_string!(
               ~s[@has_any_word("The Quick Brown Fox", "red fox").match],
               %{}
             )
  end

  describe "lists" do
    test "empty list" do
      {:ok, ast, "", _, _, _} = Parser.parse("@[]")
      assert [] == Eval.eval!(ast, %{})
    end

    test "with integer indices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1]")

      assert 1 == Eval.eval!(ast, %{"foo" => [0, 1, 2]})
    end

    test "with indices on non-listy things" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1]")
      assert nil == Eval.eval!(ast, %{"foo" => "not a list"})
    end

    test "with binary keys" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo['a']")

      assert 1 == Eval.eval!(ast, %{"foo" => %{"a" => 1}})
    end

    test "with binary keys as variables" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[bar]")

      assert 1 == Eval.eval!(ast, %{"foo" => %{"a" => 1}, "bar" => "a"})
    end

    test "with binary keys as variables and strings" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[bar]['baz']")

      assert 1 == Eval.eval!(ast, %{"foo" => %{"a" => %{"baz" => 1}}, "bar" => "a"})
    end

    test "with function" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[day(now())]")
      today = DateTime.utc_now().day
      assert today == Eval.eval!(ast, %{"foo" => Enum.to_list(0..31)})
    end

    test "with range slices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1..3]")
      assert [1, 2, 3] == Eval.eval!(ast, %{"foo" => Enum.to_list(0..31)})
    end
  end

  test "arithmetic" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 1)")
    assert 2 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 2 * 3)")
    assert 7 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) * 3)")
    assert 9 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) / 3)")
    assert 1.0 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(6 / 2 + 1)")
    assert 4.0 == Eval.eval!(ast, %{})
  end

  test "arithmetic with decimals" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1.5 + 1.5)")
    assert 3.0 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(1.5 + 2.5 * 3.5)")
    assert 10.25 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1.5 + 2.5) * 3.5)")
    assert 14.00 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1.5 + 2.5) / 3.5)")
    assert 1.1428571428571428 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(6.8 / 2.0 + 1.5)")
    assert 4.9 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(2.002 * 0.05)")
    assert 0.10010 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 > 0.5)")
    assert true == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 >= 2.0)")
    assert true == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 < 0.5)")
    assert false == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 <= 2.0)")
    assert true == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(2 == 2.0)")
    assert true == Eval.eval!(ast, %{})
  end

  test "text" do
    assert "hello Bob" ==
             Expression.evaluate_as_string!("hello @contact.name", %{
               "contact" => %{"name" => "Bob"}
             })
  end

  describe "comparing dates and ISO8601 strings" do
    test "using ==, =, != to compare a date an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a == \"2024-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2024-01-01]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a = \"2024-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2024-01-01]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a != \"2024-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2024-01-04]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a != \"2024-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2024-01-01]})
    end

    test "using < to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a < \"2024-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a < \"2019-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a < \"2019-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2019-01-01]})
    end

    test "using <= to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2024-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2019-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2019-01-01]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2019-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})
    end

    test "using > to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2024-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2019-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2019-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2019-01-01]})
    end

    test "using >= to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a >= \"2024-01-01\")")
      assert false == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a >= \"2019-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2019-01-01]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a >= \"2019-01-01\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})
    end

    test "a date can be compared to an ISO8601 string representation of a datetime" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2020-11-16T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~D[2020-11-16]})
    end
  end

  describe "comparing datetimes and ISO8601 strings" do
    test "using ==, =, != to compare a date an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a == \"2024-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2024-01-01 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a = \"2024-01-01T10:40:50.277483Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2024-01-01 10:40:50.277483Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a != \"2024-01-01T10:40:50.277484Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2024-01-04 10:40:50.277484Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a != \"2024-01-01T10:40:50.277485Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2024-01-01 10:40:50.277485Z]})
    end

    test "using < to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a < \"2024-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2024-01-01 10:39:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a < \"2019-01-01T10:40:50.277482Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a < \"2019-01-01T10:40:50.277482Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2019-01-01 10:40:50.277482Z]})
    end

    test "using <= to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2024-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2019-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2019-01-01 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a <= \"2019-01-01T10:40:50.277482Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})
    end

    test "using > to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2024-01-01T10:40:50.277482Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2019-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2019-01-01T10:40:50.277482Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2019-01-01 10:40:50.277482Z]})
    end

    test "using >= to compare a date to an ISO8601 string representation of a date" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a >= \"2024-01-01T10:40:50.277482Z\")")
      assert false == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a >= \"2019-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2019-01-01 10:40:50.277482Z]})

      {:ok, ast, "", _, _, _} = Parser.parse("@(a >= \"2019-01-01T10:40:50.277482Z\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2020-11-16 10:40:50.277482Z]})
    end

    test "a date can be compared to an ISO8601 string representation of a datetime" do
      {:ok, ast, "", _, _, _} = Parser.parse("@(a > \"2020-11-16\")")
      assert true == Eval.eval!(ast, %{"a" => ~U[2023-11-16 10:40:50.277482Z]})
    end
  end
end
