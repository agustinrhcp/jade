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
      .on_err { |(err, _)| fail err } => Ok([ast, _])

    SemanticAnalyzer
      .analyze(ast)
      .on_err { |errors| fail errors.first } => Ok([analyzed_ast, _])

    TypeChecker.check(analyzed_ast)
      .on_err { |errors| fail errors.first  } => Ok([typechecked_ast, _])

    Generator.generate(typechecked_ast)
  end
end
