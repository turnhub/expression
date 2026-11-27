defmodule StringFunctionsTypeTest do
  @moduledoc """
  Systematic type-matrix tests for the STRING category of expression functions.

  These tests DOCUMENT CURRENT BEHAVIOR of the V1 engine — they do not endorse
  it. Crashes are pinned with `assert_raise` so behavioral changes surface in
  CI. Surprising-but-real behaviors get a `# Surprising:` comment explaining
  the mechanism.

  Covered: proper, len, left, right, mid, substitute, rept, trim (unimplemented
  finding), clean, char, code, unicode, unichar, split, word, word_count,
  word_slice, first_word, remove_first_word, remove_last_word, read_digits,
  url_encode, url_decode, regex_capture, regex_named_capture.
  Excluded: upper and lower — already covered by the pilot in expression_test.exs.

  NOTE on context coercion: `Expression.Context` coerces context values BEFORE
  callbacks see them — numeric-looking strings ("123", "3.14") become numbers,
  and ISO-date / "true"/"false" strings become structs/booleans. To exercise a
  function with a genuine string argument, the string is embedded as a LITERAL
  in the expression source (e.g. `proper("foo bar")`), not passed via context.

  A recurring theme below: several functions normalise their input with
  `to_string/1` (tolerating nil/numbers), while sibling functions call
  `String.split/3` or pattern-match directly (crashing on the same inputs).
  These asymmetries are accidental but real, and are pinned as such.
  """
  use ExUnit.Case, async: true

  import Expression.Test.TypeTestMatrix

  describe "proper/1 type handling" do
    test "capitalizes the first letter of every word" do
      assert "Foo Bar" == Expression.evaluate_block!(~s|proper("foo bar")|)
      assert "Héllo 👋" == Expression.evaluate_block!(~s|proper("héllo 👋")|)
      assert "" == Expression.evaluate_block!(~s|proper("")|)
    end

    test "non-binary inputs return nil (is_binary guard), never raise" do
      # proper/1 guards on is_binary, so nil, numbers, booleans, lists and maps
      # all fall through to the implicit nil.
      for value <- [nil, 42, true, [1, 2], %{}] do
        assert nil == evaluate_with_value("proper(value)", value)
      end
    end

    test "extracts __value__ from complex values; nil __value__ returns nil" do
      assert "Foo Bar" == evaluate_with_value("proper(value)", complex_value("foo bar"))
      assert nil == evaluate_with_value("proper(value)", complex_value(nil))
    end
  end

  describe "len/1 type handling" do
    test "returns grapheme length, counting emoji as single graphemes" do
      assert 5 == Expression.evaluate_block!(~s|len("hello")|)
      assert 2 == Expression.evaluate_block!(~s|len("👋🌍")|)
      assert 0 == Expression.evaluate_block!(~s|len("")|)
    end

    test "nil is treated as the empty string, returning 0" do
      # Surprising: len(nil) is 0 rather than raising, because to_string(nil)
      # is the empty string "".
      assert 0 == evaluate_with_value("len(value)", nil)
    end

    test "numbers and booleans are stringified then measured" do
      # to_string(12345) -> "12345" (length 5); to_string(true) -> "true".
      assert 5 == evaluate_with_value("len(value)", 12_345)
      assert 4 == evaluate_with_value("len(value)", true)
    end

    test "lists are stringified (charlist-style) before measuring" do
      # to_string([1, 2, 3]) interprets the list as a charlist, not "[1, 2, 3]".
      assert 3 == evaluate_with_value("len(value)", [1, 2, 3])
    end

    test "maps raise Protocol.UndefinedError (no String.Chars for Map)" do
      # Known crash behavior, documented not endorsed: to_string/1 has no
      # String.Chars implementation for plain maps.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value("len(value)", %{"a" => 1})
      end
    end

    test "extracts __value__ from complex values" do
      assert 5 == evaluate_with_value("len(value)", complex_value("hello"))
      assert 0 == evaluate_with_value("len(value)", complex_value(nil))
    end
  end

  describe "left/2 type handling" do
    test "returns the first N characters, Unicode-safe" do
      assert "foo" == Expression.evaluate_block!(~s|left("foobar", 3)|)
      assert "👋🌍" == Expression.evaluate_block!(~s|left("👋🌍ab", 2)|)
      # Asking for more than available simply returns the whole string.
      assert "ab" == Expression.evaluate_block!(~s|left("ab", 10)|)
    end

    test "non-binary inputs return nil (is_binary guard)" do
      for value <- [nil, 12_345, [1, 2], %{}] do
        assert nil == evaluate_with_value("left(value, 3)", value)
      end
    end

    test "negative size raises FunctionClauseError" do
      # Known crash behavior, documented not endorsed: String.slice/3 has no
      # clause for a negative length.
      assert_raise FunctionClauseError, fn ->
        Expression.evaluate_block!(~s|left("foobar", -2)|)
      end
    end

    test "extracts __value__ from complex values" do
      assert "foo" == evaluate_with_value("left(value, 3)", complex_value("foobar"))
    end
  end

  describe "right/2 type handling" do
    test "returns the last N characters, Unicode-safe" do
      assert "ing" == Expression.evaluate_block!(~s|right("testing", 3)|)
      assert "ab" == Expression.evaluate_block!(~s|right("ab", 10)|)
      assert "" == Expression.evaluate_block!(~s|right("abc", 0)|)
    end

    test "non-binary inputs return nil (is_binary guard)" do
      for value <- [nil, 12_345, [1, 2], %{}] do
        assert nil == evaluate_with_value("right(value, 3)", value)
      end
    end

    test "extracts __value__ from complex values" do
      assert "ing" == evaluate_with_value("right(value, 3)", complex_value("testing"))
    end
  end

  describe "mid/3 type handling" do
    test "returns a substring from a 1-based start for num_chars characters" do
      assert "World" == Expression.evaluate_block!(~s|mid("Hello World", 7, 5)|)
    end

    test "nil and numbers are stringified first (to_string)" do
      # Unlike left/right, mid/3 calls to_string/1, so nil -> "" -> "" and
      # numbers are sliced as their string form.
      assert "" == evaluate_with_value("mid(value, 1, 3)", nil)
      assert "123" == evaluate_with_value("mid(value, 1, 3)", 12_345)
    end

    test "maps raise Protocol.UndefinedError" do
      # Known crash behavior, documented not endorsed: to_string/1 rejects maps.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value("mid(value, 1, 3)", %{})
      end
    end

    test "extracts __value__ from complex values" do
      assert "Hel" == evaluate_with_value("mid(value, 1, 3)", complex_value("Hello"))
    end
  end

  describe "substitute/3 type handling" do
    test "replaces all occurrences of a pattern" do
      assert "I can do" ==
               Expression.evaluate_block!(~s|substitute("I can't", "can't", "can do")|)

      # Every occurrence is replaced, not just the first.
      assert "bbnbnb" ==
               evaluate_with_value(~s|substitute(value, "a", "b")|, complex_value("banana"))

      # A pattern that does not appear leaves the subject unchanged.
      assert "abc" == Expression.evaluate_block!(~s|substitute("abc", "z", "y")|)
    end

    test "non-binary subjects return nil (is_binary guard)" do
      for value <- [nil, 42] do
        assert nil == evaluate_with_value(~s|substitute(value, "a", "b")|, value)
      end
    end

    test "extracts __value__ from complex values" do
      assert "I can do" ==
               evaluate_with_value(
                 ~s|substitute(value, "can't", "can do")|,
                 complex_value("I can't")
               )
    end
  end

  describe "rept/2 type handling" do
    test "repeats a string a given number of times" do
      assert "*****" == Expression.evaluate_block!(~s|rept("*", 5)|)
      assert "" == Expression.evaluate_block!(~s|rept("a", 0)|)
    end

    test "non-binary values return nil (is_binary guard)" do
      for value <- [nil, 42] do
        assert nil == evaluate_with_value("rept(value, 5)", value)
      end
    end

    test "negative count raises ArgumentError" do
      # Known crash behavior, documented not endorsed: String.duplicate/2
      # rejects a negative count.
      assert_raise ArgumentError, fn -> Expression.evaluate_block!(~s|rept("a", -1)|) end
    end

    test "extracts __value__ from complex values" do
      assert "xxx" == evaluate_with_value("rept(value, 3)", complex_value("x"))
    end
  end

  describe "trim/1 dispatch (string category, but NOT implemented)" do
    # FINDING: there is no `trim` callback in Expression.Callbacks.Standard, so
    # the dispatcher returns the "not implemented" error string for every call.
    # FLOIP defines trim() but this engine never implemented it.
    test "every invocation returns the 'trim is not implemented' error string" do
      assert ~s|ERROR: "trim is not implemented."| ==
               Expression.evaluate_block!(~s|trim("  hi  ")|)

      assert ~s|ERROR: "trim is not implemented."| ==
               evaluate_with_value("trim(value)", nil)
    end
  end

  describe "clean/1 type handling" do
    test "removes non-printable characters" do
      assert "ABC" == evaluate_with_value("clean(value)", <<65, 0, 66, 0, 67>>)
      # Printable Unicode (including emoji) is preserved.
      assert "héllo👋" == Expression.evaluate_block!(~s|clean("héllo👋")|)
    end

    test "nil and numbers are stringified (to_string), never raise" do
      assert "" == evaluate_with_value("clean(value)", nil)
      assert "42" == evaluate_with_value("clean(value)", 42)
    end

    test "maps raise Protocol.UndefinedError" do
      # Known crash behavior, documented not endorsed: to_string/1 rejects maps.
      assert_raise Protocol.UndefinedError, fn -> evaluate_with_value("clean(value)", %{}) end
    end

    test "extracts __value__ from complex values" do
      assert "AB" == evaluate_with_value("clean(value)", complex_value(<<65, 0, 66>>))
    end
  end

  describe "char/1 type handling" do
    test "returns the single byte for a codepoint via <<code>>" do
      assert "A" == Expression.evaluate_block!("char(65)")
    end

    test "is byte-based, not codepoint-based: emits raw (possibly invalid) bytes" do
      # Surprising: char/1 builds <<code>> (a single byte), so 233 yields the
      # Latin-1 byte <<233>>, which is NOT valid UTF-8, rather than "é".
      result = Expression.evaluate_block!("char(233)")
      assert <<233>> == result
      refute String.valid?(result)
    end

    test "wraps modulo 256: negative and >255 codes truncate to one byte" do
      # Surprising: <<-1>> == <<255>> and <<256>> == <<0>>; no validation.
      assert <<255>> == Expression.evaluate_block!("char(-1)")
      assert <<0>> == Expression.evaluate_block!("char(256)")
    end

    test "nil, strings and floats raise ArgumentError" do
      # Known crash behavior, documented not endorsed: <<code>> requires an
      # integer; nil, a string literal and a float all fail binary construction.
      assert_raise ArgumentError, fn -> evaluate_with_value("char(value)", nil) end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!(~s|char("A")|) end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!("char(65.5)") end
    end

    test "extracts __value__ from complex values" do
      assert "A" == evaluate_with_value("char(value)", complex_value(65))
    end
  end

  describe "code/1 type handling" do
    test "returns the numeric code of the first character" do
      assert 65 == Expression.evaluate_block!(~s|code("A")|)
    end

    test "nil returns nil (guarded with `if code`)" do
      assert nil == evaluate_with_value("code(value)", nil)
    end

    test "empty string and multi-byte first chars raise MatchError" do
      # Known crash behavior, documented not endorsed: code/1 matches the input
      # against the single-byte pattern <<code>>, which fails for "" and for any
      # multi-byte first grapheme (e.g. an emoji).
      assert_raise MatchError, fn -> Expression.evaluate_block!(~s|code("")|) end
      assert_raise MatchError, fn -> Expression.evaluate_block!(~s|code("👋")|) end
    end

    test "non-binary truthy values (e.g. an integer) raise MatchError" do
      # Known crash behavior, documented not endorsed: an integer is truthy so
      # it enters the body, then fails the <<code>> = code match.
      assert_raise MatchError, fn -> evaluate_with_value("code(value)", 65) end
    end

    test "extracts __value__ from complex values" do
      assert 65 == evaluate_with_value("code(value)", complex_value("A"))
    end
  end

  describe "unicode/1 type handling" do
    test "returns the Unicode codepoint of the first character" do
      assert 65 == Expression.evaluate_block!(~s|unicode("A")|)
      assert 233 == Expression.evaluate_block!(~s|unicode("é")|)
    end

    test "nil, empty string and non-strings raise MatchError" do
      # Known crash behavior, documented not endorsed: unicode/1 matches
      # <<code::utf8>> against its argument with no guard; nil, "" and integers
      # all fail the match.
      assert_raise MatchError, fn -> evaluate_with_value("unicode(value)", nil) end
      assert_raise MatchError, fn -> Expression.evaluate_block!(~s|unicode("")|) end
      assert_raise MatchError, fn -> evaluate_with_value("unicode(value)", 65) end
    end

    test "extracts __value__ from complex values" do
      assert 233 == evaluate_with_value("unicode(value)", complex_value("é"))
    end
  end

  describe "unichar/1 type handling" do
    test "returns the Unicode character for a codepoint (utf8-aware)" do
      assert "A" == Expression.evaluate_block!("unichar(65)")
      assert "é" == Expression.evaluate_block!("unichar(233)")
      # Unlike char/1, unichar/1 is codepoint-aware and handles astral planes.
      assert "👋" == Expression.evaluate_block!("unichar(128075)")
    end

    test "nil, strings and negative/invalid codepoints raise ArgumentError" do
      # Known crash behavior, documented not endorsed: <<code::utf8>> requires a
      # valid non-negative codepoint integer.
      assert_raise ArgumentError, fn -> evaluate_with_value("unichar(value)", nil) end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!(~s|unichar("A")|) end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!("unichar(-1)") end
    end

    test "extracts __value__ from complex values" do
      assert "é" == evaluate_with_value("unichar(value)", complex_value(233))
    end
  end

  describe "split/1 and split/2 type handling" do
    test "split/1 splits on single spaces; split/2 on a custom pattern" do
      assert ["a", "b", "c"] == Expression.evaluate_block!(~s|split("a b c")|)
      assert ["a", "b", "c"] == Expression.evaluate_block!(~s|split("a,b,c", ",")|)
    end

    test "nil and numbers raise FunctionClauseError" do
      # Known crash behavior, documented not endorsed: split calls String.split/2
      # directly on the (uncoerced) input, which has no clause for non-binaries.
      assert_raise FunctionClauseError, fn -> evaluate_with_value("split(value)", nil) end
      assert_raise FunctionClauseError, fn -> evaluate_with_value("split(value)", 42) end
    end

    test "extracts __value__ from complex values" do
      assert ["a", "b", "c"] == evaluate_with_value("split(value)", complex_value("a b c"))
    end
  end

  describe "word/2 and word/3 type handling" do
    test "extracts the nth word, splitting on punctuation by default" do
      assert "cow" == Expression.evaluate_block!(~s|word("hello cow-boy", 2)|)
      # by_spaces: true splits only on spaces, keeping the hyphenated token.
      assert "cow-boy" == Expression.evaluate_block!(~s|word("hello cow-boy", 2, true)|)
      # Negative n counts back from the end.
      assert "boy" == Expression.evaluate_block!(~s|word("hello cow-boy", -1)|)
    end

    test "nil and numbers are stringified first (to_string)" do
      # to_string(nil) -> "" yields a single empty word at index 1.
      assert "" == evaluate_with_value("word(value, 1)", nil)
      assert "42" == evaluate_with_value("word(value, 1)", 42)
    end

    test "out-of-range index raises MatchError" do
      # Known crash behavior, documented not endorsed: Enum.slice returns [] for
      # an out-of-range index, which fails the `[part] = ...` match.
      assert_raise MatchError, fn -> Expression.evaluate_block!(~s|word("a b", 5)|) end
    end

    test "extracts __value__ from complex values" do
      assert "cow" == evaluate_with_value("word(value, 2)", complex_value("hello cow-boy"))
    end
  end

  describe "word_count/1 and word_count/2 type handling" do
    test "counts words, splitting on punctuation by default" do
      assert 3 == Expression.evaluate_block!(~s|word_count("hello cow-boy")|)
      # by_spaces: true counts the hyphenated token as one word.
      assert 2 == Expression.evaluate_block!(~s|word_count("hello cow-boy", true)|)
    end

    test "the empty string counts as 1 word, not 0" do
      # Surprising: String.split("", pattern) returns [""], so the count is 1.
      assert 1 == Expression.evaluate_block!(~s|word_count("")|)
    end

    test "nil short-circuits to 0, but numbers raise FunctionClauseError" do
      # Surprising asymmetry: word_count has an explicit `is_nil` guard returning
      # 0, but no to_string fallback — so a number falls straight into
      # String.split/2 and crashes.
      assert 0 == evaluate_with_value("word_count(value)", nil)

      assert_raise FunctionClauseError, fn -> evaluate_with_value("word_count(value)", 42) end
    end

    test "extracts __value__ from complex values" do
      assert 3 == evaluate_with_value("word_count(value)", complex_value("hello cow-boy"))
    end
  end

  describe "word_slice/2, /3 and /4 type handling" do
    test "slices a range of words" do
      assert "expressions are fun" ==
               Expression.evaluate_block!(~s|word_slice("FLOIP expressions are fun", 2)|)

      assert "expressions are" ==
               Expression.evaluate_block!(~s|word_slice("FLOIP expressions are fun", 2, 4)|)

      # Negative start counts back from the end.
      assert "fun" ==
               Expression.evaluate_block!(~s|word_slice("FLOIP expressions are fun", -1)|)

      # Negative stop is relative to the end too.
      assert "a b" == Expression.evaluate_block!(~s|word_slice("a b c d", 1, -2)|)
    end

    test "nil is stringified to the empty string, returning empty" do
      assert "" == evaluate_with_value("word_slice(value, -1)", nil)
    end

    test "a start of 0 raises CondClauseError (no clause for start == 0)" do
      # Known crash behavior, documented not endorsed: word_slice/2 only has
      # cond clauses for start > 0 and start < 0, so 0 falls through.
      assert_raise CondClauseError, fn ->
        Expression.evaluate_block!(~s|word_slice("a b c", 0)|)
      end
    end

    test "extracts __value__ from complex values" do
      assert "expressions are fun" ==
               evaluate_with_value(
                 "word_slice(value, 2)",
                 complex_value("FLOIP expressions are fun")
               )
    end
  end

  describe "first_word/1 type handling" do
    test "returns the first space-delimited word" do
      assert "foo" == Expression.evaluate_block!(~s|first_word("foo bar baz")|)
    end

    test "nil and numbers are stringified first (to_string)" do
      # first_word always splits a non-empty list, so nil -> "" -> [""] -> "".
      assert "" == evaluate_with_value("first_word(value)", nil)
      assert "42" == evaluate_with_value("first_word(value)", 42)
    end

    test "maps raise Protocol.UndefinedError" do
      # Known crash behavior, documented not endorsed: to_string/1 rejects maps.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value("first_word(value)", %{})
      end
    end

    test "extracts __value__ from complex values" do
      assert "foo" == evaluate_with_value("first_word(value)", complex_value("foo bar"))
    end
  end

  describe "remove_first_word/1 and /2 type handling" do
    test "removes the first word, default or custom separator" do
      assert "bar" == Expression.evaluate_block!(~s|remove_first_word("foo bar")|)
      assert "bar" == Expression.evaluate_block!(~s|remove_first_word("foo-bar", "-")|)
      # A single word leaves nothing behind.
      assert "" == Expression.evaluate_block!(~s|remove_first_word("foo")|)
    end

    test "nil and numbers are stringified first (to_string), returning empty" do
      # remove_first_word uses to_string, so non-strings degrade gracefully.
      assert "" == evaluate_with_value("remove_first_word(value)", nil)
      assert "" == evaluate_with_value(~s|remove_first_word(value, "-")|, nil)
      assert "" == evaluate_with_value("remove_first_word(value)", 42)
    end

    test "extracts __value__ from complex values" do
      assert "bar" == evaluate_with_value("remove_first_word(value)", complex_value("foo bar"))
    end
  end

  describe "remove_last_word/1 and /2 type handling" do
    test "removes the last word, default or custom separator" do
      assert "foo" == Expression.evaluate_block!(~s|remove_last_word("foo bar")|)
      assert "foo" == Expression.evaluate_block!(~s|remove_last_word("foo-bar", "-")|)
      assert "" == Expression.evaluate_block!(~s|remove_last_word("foo")|)
    end

    test "nil and numbers raise FunctionClauseError (NO to_string, unlike remove_first_word)" do
      # Surprising asymmetry, documented not endorsed: remove_last_word calls
      # String.split/2 on the raw input without the to_string normalisation that
      # remove_first_word performs, so the same nil/number inputs crash here.
      assert_raise FunctionClauseError, fn ->
        evaluate_with_value("remove_last_word(value)", nil)
      end

      assert_raise FunctionClauseError, fn ->
        evaluate_with_value("remove_last_word(value)", 42)
      end
    end

    test "extracts __value__ from complex values" do
      assert "foo" == evaluate_with_value("remove_last_word(value)", complex_value("foo bar"))
    end
  end

  describe "read_digits/1 type handling" do
    test "spells out digits and the plus sign for TTS" do
      assert "plus two seven one" == Expression.evaluate_block!(~s|read_digits("+271")|)
      # Non-digit, non-plus characters are dropped entirely.
      assert "" == Expression.evaluate_block!(~s|read_digits("abc")|)
    end

    test "nil and numbers are stringified first (to_string)" do
      assert "" == evaluate_with_value("read_digits(value)", nil)
      # An integer has no leading '+', so only its digits are spelled out.
      assert "two seven one" == evaluate_with_value("read_digits(value)", 271)
    end

    test "maps raise Protocol.UndefinedError" do
      # Known crash behavior, documented not endorsed: to_string/1 rejects maps.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value("read_digits(value)", %{})
      end
    end

    test "extracts __value__ from complex values" do
      assert "plus two seven one" ==
               evaluate_with_value("read_digits(value)", complex_value("+271"))
    end
  end

  describe "url_encode/1 type handling" do
    test "percent-encodes a string" do
      assert "hello%20world" == Expression.evaluate_block!(~s|url_encode("hello world")|)
      # URI.encode leaves sub-delims like & untouched by default.
      assert "a%20b&c" == Expression.evaluate_block!(~s|url_encode("a b&c")|)
    end

    test "nil and numbers are stringified first (to_string)" do
      assert "" == evaluate_with_value("url_encode(value)", nil)
      assert "42" == evaluate_with_value("url_encode(value)", 42)
    end

    test "maps raise Protocol.UndefinedError" do
      # Known crash behavior, documented not endorsed: to_string/1 rejects maps.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value("url_encode(value)", %{})
      end
    end

    test "extracts __value__ from complex values" do
      assert "hello%20world" ==
               evaluate_with_value("url_encode(value)", complex_value("hello world"))
    end
  end

  describe "url_decode/1 type handling" do
    test "percent-decodes a string" do
      assert "hello world" == Expression.evaluate_block!(~s|url_decode("hello%20world")|)
    end

    test "nil and numbers raise FunctionClauseError (NO to_string, unlike url_encode)" do
      # Surprising asymmetry, documented not endorsed: url_decode calls
      # URI.decode/1 directly on its input without the to_string normalisation
      # that url_encode performs, so non-binaries crash here but not there.
      assert_raise FunctionClauseError, fn -> evaluate_with_value("url_decode(value)", nil) end
      assert_raise FunctionClauseError, fn -> evaluate_with_value("url_decode(value)", 42) end
    end

    test "extracts __value__ from complex values" do
      assert "hello world" ==
               evaluate_with_value("url_decode(value)", complex_value("hello%20world"))
    end
  end

  describe "regex_capture/2 type handling" do
    test "returns capture groups, or nil when nothing matches" do
      assert ["ing"] == Expression.evaluate_block!(~s|regex_capture("testing", "test(.+)")|)
      assert nil == Expression.evaluate_block!(~s|regex_capture("testing", "foo(.+)")|)
    end

    test "non-binary subjects return nil (is_binary guard)" do
      assert nil == evaluate_with_value(~s|regex_capture(value, "x")|, nil)
      assert nil == evaluate_with_value(~s|regex_capture(value, "4")|, 42)
    end

    test "an invalid regex pattern raises Regex.CompileError" do
      # Known crash behavior, documented not endorsed: Regex.compile!/1 raises
      # on a malformed pattern rather than returning an error.
      assert_raise Regex.CompileError, fn ->
        Expression.evaluate_block!(~s|regex_capture("testing", "(")|)
      end
    end

    test "extracts __value__ from complex values" do
      assert ["ing"] ==
               evaluate_with_value(~s|regex_capture(value, "test(.+)")|, complex_value("testing"))
    end
  end

  describe "regex_named_capture/2 type handling" do
    test "returns a map of named captures, or an empty map when nothing matches" do
      assert %{"m" => "ing"} ==
               Expression.evaluate_block!(~s|regex_named_capture("testing", "test(?P<m>.+)")|)

      assert %{} ==
               Expression.evaluate_block!(~s|regex_named_capture("testing", "foo(?P<m>.+)")|)
    end

    test "non-binary subjects return an empty map (explicit else branch)" do
      # Unlike regex_capture (which returns nil), the named variant has an else
      # branch returning %{} for non-binary subjects.
      assert %{} == evaluate_with_value(~s|regex_named_capture(value, "x")|, nil)
    end

    test "extracts __value__ from complex values" do
      assert %{"m" => "ing"} ==
               evaluate_with_value(
                 ~s|regex_named_capture(value, "test(?P<m>.+)")|,
                 complex_value("testing")
               )
    end
  end
end
