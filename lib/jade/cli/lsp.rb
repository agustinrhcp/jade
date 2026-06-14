require 'jade/lsp'

module Jade
  module CLI
    module Lsp
      module_function

      def run(_argv)
        Jade::LSP::Server.new.run
      end
    end
  end
end
