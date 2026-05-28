require 'jade/formatter/helper'
require 'jade/formatter/pattern'
require 'jade/formatter/type'
require 'jade/formatter/exposing'
require 'jade/formatter/leaves'
require 'jade/formatter/accesses'
require 'jade/formatter/bindings'
require 'jade/formatter/calls'
require 'jade/formatter/collections'
require 'jade/formatter/declarations'
require 'jade/formatter/module_node'
require 'jade/formatter/body'
require 'jade/formatter/function_declaration'
require 'jade/formatter/lambda'
require 'jade/formatter/infix_application'
require 'jade/formatter/if_then_else'
require 'jade/formatter/case_of'
require 'jade/formatter/case_of_branch'

module Jade
  module Formatter
    extend self
    extend Helper

    # Constants live at the top-level module so unqualified references
    # resolve via Ruby's lexical-scope constant lookup from any nested
    # per-node module (which only `extend`s Helper — `extend` doesn't
    # bring constants in).
    INDENT     = "  "
    LINE_LIMIT = 80

    def format(node, comments:, source:, indent: 0)
      Frontend::CommentAttacher
        .attach(node, comments, source)
        .then { format_node(it, indent:, source:) }
    end
  end
end
