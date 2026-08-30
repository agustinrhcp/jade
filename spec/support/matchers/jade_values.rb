# Matchers over Jade's own values — a `Jade::Maybe`, a union variant. Only the
# compiler's specs see values of that shape; an application gets wire data, so
# these stay here rather than in the gem.
::RSpec::Matchers.define :look_like do |name, *positional, **named|
  match do |actual|
    @actual = actual
    Jade::Tasks::Matcher.match?(actual, name, positional, named)
  end

  failure_message do
    args = (positional.map(&:inspect) + named.map { |k, v| "#{k}: #{v.inspect}" }).join(', ')
    "expected #{@actual.inspect} to look like #{name}(#{args})"
  end
end

{
  just:    'Jade::Maybe::Just',
  nothing: 'Jade::Maybe::Nothing',
}.each do |kind, full_name|
  ::RSpec::Matchers.define :"be_#{kind}" do |*args, **named|
    match do |actual|
      @actual = actual
      if args.empty? && named.empty?
        actual.respond_to?(:"#{kind}?") && actual.public_send(:"#{kind}?")
      else
        Jade::Tasks::Matcher.match?(actual, full_name, args, named)
      end
    end

    failure_message do
      if args.empty? && named.empty?
        "expected #{@actual.inspect} to respond truthy to .#{kind}?"
      else
        inner = (args.map(&:inspect) + named.map { |k, v| "#{k}: #{v.inspect}" }).join(', ')
        "expected #{@actual.inspect} to be #{kind.to_s.capitalize}(#{inner})"
      end
    end
  end
end
