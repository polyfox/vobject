defprotocol VCard.Value do
  @fallback_to_any true
  @spec encode(value :: term, params :: map) :: iodata
  def encode(value, params \\ %{})
end

alias VCard.Value

