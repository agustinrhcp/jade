require 'ast/pretty_printer'

RSpec::Matchers.define :match_ast_node do |expected_node|
  match do |actual_node|
    actual_node.class == expected_node.class &&
      AST::PrettyPrinter.print(actual_node) ==
        AST::PrettyPrinter.print(expected_node)
  end

  failure_message do |actual_node|
    "expected node:\n#{AST::PrettyPrinter.print(expected_node)}\n\n" \
    "got:\n#{AST::PrettyPrinter.print(actual_node)}"
  end
end

RSpec::Matchers.define :match_many_ast_nodes do |*expected_nodes|
  match do |actual_nodes|
    return false unless actual_nodes.size == expected_nodes.size

    actual_nodes.zip(expected_nodes).all? do |actual, expected|
      matcher =
        case expected
        when Array then match_ast_node(*expected)
        when Hash then match_ast_node(**expected)
        else match_ast_node(expected)
        end

      matcher.matches?(actual)
    end
  end

  failure_message do |actual_nodes|
    "Expected:\n" +
      expected_nodes.map(&:pretty_print).join("\n") +
      "\n\nGot:\n" +
      actual_nodes.map(&:pretty_print).join("\n")
  end
end
