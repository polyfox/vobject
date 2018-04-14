defmodule ICalendar.RFC6868 do
  @doc ~S"""
  RFC6868 parameter encoding unescape.

  " \n and ^ have to be unescaped.
  """
  @spec unescape(String.t) :: String.t
  def unescape(string) do
    Regex.replace(~r/\^['n^]/, string, fn 
      "^'" -> ~s(")
      "^n" -> "\n"
      "^^" -> "^"
    end)
  end

  @doc ~S"""
  RFC6868 parameter encoding escape.

  " \n and ^ have to be escaped.
  """
  @spec escape(String.t) :: String.t
  def escape(string) do
    Regex.replace(~r/["\n^]/, string, fn 
      ~s(") -> "^'"
      "\n" -> "^n"
      "^" -> "^^"
    end)
  end
end
