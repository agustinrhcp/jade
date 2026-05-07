module Jade
  Task = Data.define(:_1) do
    def run = _1.call

    def self.ok(&block)
      new(-> { Jade::Result::Ok[block.call] })
    end

    def self.error(&block)
      new(-> { Jade::Result::Err[block.call] })
    end
  end
end
