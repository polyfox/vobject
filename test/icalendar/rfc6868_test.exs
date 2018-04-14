defmodule ICalendar.RFC6868Test do
  use ExUnit.Case
  doctest ICalendar.RFC6868
  alias ICalendar.RFC6868

  test "unescape" do
    assert RFC6868.unescape("George Herman ^'Babe^' Ruth") == ~s(George Herman "Babe" Ruth)
    # will not unescape any other ^ characters
    assert RFC6868.unescape("Hello^World") == ~s(Hello^World)
  end

  test "escape" do
    assert RFC6868.escape(~s(George Herman "Babe" Ruth)) == ~s(George Herman ^'Babe^' Ruth)
    assert RFC6868.escape("Hello^World") == ~s(Hello^^World)
  end

  test "roundtrip" do
    input = ~S(caret ^ dquote " newline \n end)

    res =
      input
      |> RFC6868.escape()
      |> RFC6868.unescape()

    assert input == res
  end
end
