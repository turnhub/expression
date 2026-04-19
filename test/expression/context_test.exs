defmodule Expression.ContextTest do
  use ExUnit.Case
  alias Expression.Context

  test "new context from a context containing a date string in dd/mm/yyyy" do
    context = %{"block" => %{"value" => %{"birth_date" => "19/10/2002"}}}

    assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-19]}}} =
             Context.new(context)
  end

  test "new context from a context containing a date string in dd/mm/yyyy starting with 0" do
    context = %{"block" => %{"value" => %{"birth_date" => "09/10/2002"}}}

    assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-09]}}} =
             Context.new(context)
  end

  test "new context from a context containing a date string in dd-mm-yyyy" do
    context = %{"block" => %{"value" => %{"birth_date" => "19-10-2002"}}}

    assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-19]}}} =
             Context.new(context)
  end

  test "new context from a context containing a date string in dd-mm-yyyy starting with 0" do
    context = %{"block" => %{"value" => %{"birth_date" => "09-10-2002"}}}

    assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-09]}}} =
             Context.new(context)
  end

  test "new context from a context containing a datetime string" do
    context = %{"block" => %{"value" => %{"program_start_date" => "2022-11-10T13:40:05.921378"}}}

    assert %{"block" => %{"value" => %{"program_start_date" => ~U[2022-11-10 13:40:05.921378Z]}}} =
             Context.new(context)
  end

  test "new context from a context containing a datetime string with microseconds precision 7" do
    context = %{"block" => %{"value" => %{"program_start_date" => "2022-11-10T13:40:05.9213782"}}}

    # Assert that the microseconds are truncated to precision 6 (the maximum precision supported by Elixir's DateTime)
    assert %{"block" => %{"value" => %{"program_start_date" => ~U[2022-11-10 13:40:05.921378Z]}}} =
             Context.new(context)
  end

  test "new context from a context containing numbers" do
    values = [
      %{"score" => 1234},
      %{"rate" => 1.1234567}
    ]

    for context <- values do
      # Assert that the number is not parsed
      assert Context.new(context) == context
    end
  end

  test "new context with zero as a string" do
    # Assert that the string "0" is parsed as a number
    assert Context.new(%{"zero" => "0"}) == %{"zero" => 0}
  end

  test "new context from a context containing a string starting with zero" do
    values = [
      %{"national_id" => "01234567"},
      %{"code" => "01234abc"},
      %{"rate" => "0.1234567"},
      %{"password" => "0.123abc"}
    ]

    for context <- values do
      # Assert that the string starting with zero is not parsed as number
      assert Context.new(context) == context
    end
  end

  describe "lowercase_keys option" do
    test "default: keys are lowercased" do
      assert %{"name" => "Jane"} = Context.new(%{Name: "Jane"})
    end

    test "lowercase_keys: true is the same as default" do
      assert %{"name" => "Jane"} = Context.new(%{Name: "Jane"}, lowercase_keys: true)
    end

    test "lowercase_keys: false preserves original key casing" do
      ctx = Context.new(%{"FirstName" => "Jane", "lastName" => "Doe"}, lowercase_keys: false)
      assert ctx["FirstName"] == "Jane"
      assert ctx["lastName"] == "Doe"
      refute Map.has_key?(ctx, "firstname")
    end

    test "lowercase_keys: false still converts atom keys to strings" do
      ctx = Context.new(%{Name: "Jane"}, lowercase_keys: false)
      assert ctx["Name"] == "Jane"
    end

    test "lowercase_keys: false works with nested maps" do
      ctx =
        Context.new(
          %{"Contact" => %{"FirstName" => "Jane"}},
          lowercase_keys: false
        )

      assert ctx["Contact"]["FirstName"] == "Jane"
    end

    test "expressions work with case-preserved keys via case-insensitive lookup" do
      ctx =
        Expression.Context.new(
          %{"FirstName" => "Jane"},
          lowercase_keys: false
        )

      # Parser lowercases @firstname, case-insensitive lookup finds "FirstName"
      assert "Jane" == Expression.evaluate_as_string!("@firstname", ctx)
    end

    test "expressions work with mixed-case nested keys" do
      ctx =
        Expression.Context.new(
          %{"Contact" => %{"FirstName" => "Jane"}},
          lowercase_keys: false
        )

      assert "Jane" == Expression.evaluate_as_string!("@contact.firstname", ctx)
    end
  end

  describe "coerce_strings option" do
    test "default: strings are coerced" do
      assert %{"flag" => true} = Context.new(%{"flag" => "true"})
      assert %{"num" => 42} = Context.new(%{"num" => "42"})
    end

    test "coerce_strings: true is the same as default" do
      assert %{"flag" => true} = Context.new(%{"flag" => "true"}, coerce_strings: true)
    end

    test "coerce_strings: false preserves string values" do
      ctx = Context.new(%{"flag" => "true", "num" => "42"}, coerce_strings: false)
      assert ctx["flag"] == "true"
      assert ctx["num"] == "42"
    end

    test "coerce_strings: false preserves zero as string" do
      ctx = Context.new(%{"zero" => "0"}, coerce_strings: false)
      assert ctx["zero"] == "0"
    end

    test "coerce_strings: true coerces datetime strings" do
      ctx = Context.new(%{"date" => "2020-12-13T23:34:45"}, coerce_strings: true)
      assert %DateTime{} = ctx["date"]
    end

    test "coerce_strings: false preserves datetime strings" do
      ctx = Context.new(%{"date" => "2020-12-13T23:34:45"}, coerce_strings: false)
      assert ctx["date"] == "2020-12-13T23:34:45"
    end

    test "coerce_strings: false still processes nested maps" do
      ctx =
        Context.new(
          %{"block" => %{"value" => "42"}},
          coerce_strings: false
        )

      assert ctx["block"]["value"] == "42"
    end

    test "coerce_strings: false is backwards compat with skip_context_evaluation?" do
      ctx1 = Context.new(%{"flag" => "True"}, coerce_strings: false)
      ctx2 = Context.new(%{"flag" => "True"}, skip_context_evaluation?: true)
      assert ctx1 == ctx2
    end
  end

  describe "combined options" do
    test "both options can be used together" do
      ctx =
        Context.new(
          %{"FirstName" => "Jane", "Active" => "true"},
          lowercase_keys: false,
          coerce_strings: false
        )

      assert ctx["FirstName"] == "Jane"
      assert ctx["Active"] == "true"
    end

    test "build/2 passes options through" do
      ctx =
        Expression.Context.build(
          %{"FirstName" => "Jane"},
          private: %{secret: "hidden"},
          lowercase_keys: false
        )

      assert ctx.vars["FirstName"] == "Jane"
      assert ctx.private == %{secret: "hidden"}

      # Case-insensitive lookup works through the struct
      assert "Jane" == Expression.evaluate_as_string!("@firstname", ctx)
    end
  end

  describe "context is parsed correctly when using the `skip_context_evaluation?` option" do
    test "string values in context that resemble booleans should not be parsed as booleans" do
      # By default (without the flag) boolean-ish string values as parsed as booleans
      assert %{"block" => %{"response" => true}} ==
               Context.new(%{
                 "block" => %{"response" => "True"}
               })

      # With the flag set to true they are kept as strings
      assert %{"block" => %{"response" => "True"}} ==
               Context.new(%{"block" => %{"response" => "True"}},
                 skip_context_evaluation?: true
               )

      assert %{"block" => %{"response" => "true"}} ==
               Context.new(
                 %{"block" => %{"response" => "true"}},
                 skip_context_evaluation?: true
               )
    end

    test "string values in context that resemble numbers should not be parsed as numbers" do
      assert %{
               "ref_buttons_7bef16" => %{
                 "__value__" => "2",
                 "index" => 1,
                 "label" => "2",
                 "name" => "2"
               }
             } ==
               Context.new(
                 %{
                   "ref_Buttons_7bef16" => %{
                     "__value__" => "2",
                     "index" => 1,
                     "label" => "2",
                     "name" => "2"
                   }
                 },
                 skip_context_evaluation?: true
               )
    end
  end
end
