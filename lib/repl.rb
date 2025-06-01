require 'irb'
require 'parser'
require 'semantic_analyzer'
require 'generator'
require 'type_checker'

module REPL
  def self.start
    puts "Welcome to the Jade REPL"
    puts "Type Jade code. Press Ctrl+D to exit."

    IRB.setup(nil)

    workspace = IRB::WorkSpace.new(self)

    irb = IRB::Irb.new(workspace)

    IRB.conf[:MAIN_CONTEXT] = irb.context

    trap("SIGINT") { irb.signal_handle }

    context = binding
    scope = SemanticAnalyzer::Scope.new
    env = TypeChecker::Env.new

    loop do
      input = irb.context.io.prompt
      code = gets

      break unless code
      break if code == 'exit'

      tokens = Lexer.scan(code)
      case Parser.program.call(Parser::State.new(tokens))
      in Err(errors)
        puts "errors"
      in Ok([ast, _])
        analyzed_ast, scope, errors = SemanticAnalyzer.analyze(ast, scope)

        if errors.any?
          errors.each { |e| puts "error: #{e.message}" }
        else
          case TypeChecker.check(analyzed_ast, env)
          in Ok([type, env])
            ruby = Generator.generate(analyzed_ast)
            result = context.eval(ruby)
            puts "=> #{result.inspect} : #{type}"
          in Err(errors)
            puts errors
          end
        end
      end
    end
  end
end
