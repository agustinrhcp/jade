require 'lexer'
require 'parser'
require 'semantic_analyzer'
require 'type_checker'
require 'generator'
require 'result' 

module Compiler
  extend self

  def compile(source)

    Lexer
      .scan(source)
      # TODO: scanning raises an error (instead of returning a result)
      .then { |tokens| Parser::State.new(tokens) }
      .then { |tokens| Parser.program.call(tokens) }
      .and_then do |(ast, _)|
        analyzed_ast, scope, errors = SemanticAnalyzer.analyze(ast)
        fail errors.first.message if errors.any?
        TypeChecker
          .check(analyzed_ast, scope)
          .on_err { |err| fail err.message }
          .map { analyzed_ast }
      end
      .on_err { |err| fail err.message }
      .and_then { |ast| Generator.generate(ast) }
  end
end
