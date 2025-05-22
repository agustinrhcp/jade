RSpec::Matchers.define :have_tokenized do |expected_type|
  match do |tokens|
    @expected_type = expected_type

    if @index
      candidate = tokens[@index]
      @token = candidate if candidate && token_matches?(candidate)
    else
      @token = tokens.find { |t| token_matches?(t) }
    end

    !!@token
  end

  chain :at do |index|
    @index = index
  end

  chain :with do |value|
    @expected_value = value
  end

  chain :on do |pos|
    pos => { line:, column: }
    @expected_line = line
    @expected_column = column
  end

  failure_message do
    if @index
      token = tokens[@index]
      if token.nil?
        "no token at index #{@index}"
      else
        "token at index #{@index} does not match expected criteria: " \
        "expected type=#{@expected_type.inspect}" +
        (@expected_value ? ", value=#{@expected_value.inspect}" : "") +
        (@expected_line ? ", line=#{@expected_line}" : "") +
        (@expected_column ? ", column=#{@expected_column}" : "") +
        ", but got type=#{token.type.inspect}, value=#{token.value.inspect}, line=#{token.line}, column=#{token.column}"
      end
    else
      "could not find a token matching: type=#{@expected_type.inspect}" +
      (@expected_value ? ", value=#{@expected_value.inspect}" : "") +
      (@expected_line ? ", line=#{@expected_line}" : "") +
      (@expected_column ? ", column=#{@expected_column}" : "")
    end
  end

  def token_matches?(token)
    return false unless token.type == @expected_type
    return false if @expected_value && token.value != @expected_value
    return false if @expected_line && token.line != @expected_line
    return false if @expected_column && token.column != @expected_column
    true
  end
end
