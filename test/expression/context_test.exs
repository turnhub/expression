defmodule Expression.ContextTest do
  use ExUnit.Case
  alias Expression.Context

  describe "string coercion (coerce_strings: true)" do
    test "context containing a date string in dd/mm/yyyy" do
      context = %{"block" => %{"value" => %{"birth_date" => "19/10/2002"}}}

      assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-19]}}} =
               Context.new(context, coerce_strings: true)
    end

    test "context containing a date string in dd/mm/yyyy starting with 0" do
      context = %{"block" => %{"value" => %{"birth_date" => "09/10/2002"}}}

      assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-09]}}} =
               Context.new(context, coerce_strings: true)
    end

    test "context containing a date string in dd-mm-yyyy" do
      context = %{"block" => %{"value" => %{"birth_date" => "19-10-2002"}}}

      assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-19]}}} =
               Context.new(context, coerce_strings: true)
    end

    test "context containing a date string in dd-mm-yyyy starting with 0" do
      context = %{"block" => %{"value" => %{"birth_date" => "09-10-2002"}}}

      assert %{"block" => %{"value" => %{"birth_date" => ~D[2002-10-09]}}} =
               Context.new(context, coerce_strings: true)
    end

    test "context containing a datetime string" do
      context = %{
        "block" => %{"value" => %{"program_start_date" => "2022-11-10T13:40:05.921378"}}
      }

      assert %{
               "block" => %{"value" => %{"program_start_date" => ~U[2022-11-10 13:40:05.921378Z]}}
             } =
               Context.new(context, coerce_strings: true)
    end

    test "context containing a datetime string with microseconds precision 7" do
      context = %{
        "block" => %{"value" => %{"program_start_date" => "2022-11-10T13:40:05.9213782"}}
      }

      # microseconds are truncated to precision 6 (Elixir's DateTime maximum)
      assert %{
               "block" => %{"value" => %{"program_start_date" => ~U[2022-11-10 13:40:05.921378Z]}}
             } =
               Context.new(context, coerce_strings: true)
    end

    test "context containing numbers" do
      values = [
        %{"score" => 1234},
        %{"rate" => 1.1234567}
      ]

      for context <- values do
        # numbers are unchanged
        assert Context.new(context, coerce_strings: true) == context
      end
    end

    test "zero as a string is parsed as a number" do
      assert Context.new(%{"zero" => "0"}, coerce_strings: true) == %{"zero" => 0}
    end

    test "strings starting with zero are not parsed as numbers" do
      values = [
        %{"national_id" => "01234567"},
        %{"code" => "01234abc"},
        %{"rate" => "0.1234567"},
        %{"password" => "0.123abc"}
      ]

      for context <- values do
        assert Context.new(context, coerce_strings: true) == context
      end
    end
  end

  describe "v3 default behavior (no coercion, no key lowercasing)" do
    test "string values are preserved by default" do
      context = %{"birth_date" => "19/10/2002", "active" => "true", "score" => "42"}

      assert Context.new(context) == context
    end

    test "atom keys are stringified but case is preserved" do
      assert Context.new(%{Name: "Jane", AGE: 30}) == %{"Name" => "Jane", "AGE" => 30}
    end

    test "datetime strings are not coerced by default" do
      context = %{"date" => "2022-11-10T13:40:05.921378"}

      assert Context.new(context) == context
    end
  end

  describe "lowercase_keys option" do
    test "default: original key casing is preserved" do
      assert %{"Name" => "Jane"} = Context.new(%{Name: "Jane"})
    end

    test "lowercase_keys: true lowercases keys" do
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
    test "default: strings are preserved (no coercion)" do
      assert %{"flag" => "true"} = Context.new(%{"flag" => "true"})
      assert %{"num" => "42"} = Context.new(%{"num" => "42"})
    end

    test "coerce_strings: true coerces booleans and numbers" do
      assert %{"flag" => true} = Context.new(%{"flag" => "true"}, coerce_strings: true)
      assert %{"num" => 42} = Context.new(%{"num" => "42"}, coerce_strings: true)
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
end
