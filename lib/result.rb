Ok = Data.define(:ok) do
  private :ok

  def initialize(ok: nil)
    super
  end

  def map
    Ok.new(yield(ok))
  end
  alias_method :map_both, :map

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

module Results
  def self.sequence(results)
    results.reduce(Ok[[]]) do |acc, r|
      acc.and_then { |list| r.map { list + [it] } }
    end
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
  alias_method :map_both, :map_error

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
