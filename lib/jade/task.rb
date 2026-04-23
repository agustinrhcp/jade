module Jade
  Task = Data.define(:_1) do
    def run = _1.call

    def self.ok(&block)
      new(-> { ::Result::Ok[block.call] })
    end

    def self.error(&block)
      new(-> { ::Result::Err[block.call] })
    end
  end
end
