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
      .then { |tokens| Parser.module.call(tokens) }
      .on_err { |(err, _)| fail err }
      .and_then do |(ast, _)|
        analyzed_ast, context, errors = SemanticAnalyzer.analyze(ast)
        fail errors.first if errors.any?
        TypeChecker
          .check(analyzed_ast, context)
          .on_err { |err| fail Array(err).first }
          .map { analyzed_ast }
      end
      .on_err { |err| fail err.message }
      .and_then { |ast| Generator.generate(ast) }
  end
end
