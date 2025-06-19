module Result
  extend self

  def walk(list, &block)
    list.reduce(Ok[[]]) do |acc, item|
      case [acc, block.call(item)]
      in [Ok(collected), Ok(result)]
        Ok[collected + [result]]
      in [Ok, Err(err)]
        Err[err]
      in [Err, Ok]
        acc
      in [Err(acc_err), Err(err)]
        Err[acc_err + err]
      end
    end
  end
end

Ok  = Data.define(:ok) do
  private :ok

  def map
    Ok.new(yield(ok))
  end

  def and_then
    yield(ok)
  end

  def and_tap
    result = yield(ok)
    case result
    in Ok then self
    in Err then result
    end
  end

  def map_error
    self
  end

  def map2(result)
    case result
    in Ok(ok2) then Ok.new(yield(ok, ok2))
    in Err(_) then result
    end
  end

  def and_then_combine
    result = yield(ok)
    case result
    in Ok(ok2) then Ok.new([*ok, ok2])
    in Err(_) then result
    end
  end

  def on_err(_error_type = nil)
    self
  end

  def with_default(_default)
    ok
  end

  def ok?
    true
  end

  def error?
    false
  end
end

Err = Data.define(:err) do
  private :err

  def map
    self
  end

  def and_then
    self
  end

  def map_error
    Err.new(yield(err))
  end

  def map2(_)
    self
  end

  def and_tap
    self
  end

  def and_then_combine
    self
  end

  def on_err(error_type = nil)
    return yield(err) unless error_type

    case err
    when error_type
      yield(err)
    else
      self
    end
  end

  def with_default(default)
    default
  end

  def ok?
    false
  end

  def error?
    true
  end
end


