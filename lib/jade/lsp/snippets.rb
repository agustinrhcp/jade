module Jade
  module LSP
    module Snippets
      Snippet = Data.define(:label, :detail, :body)

      ALL = [
        Snippet.new(
          label: 'def',
          detail: 'function declaration',
          body: <<~SNIP.chomp,
            def ${1:name}(${2:params}) -> ${3:Type}
              ${0:body}
            end
          SNIP
        ),
        Snippet.new(
          label: 'type',
          detail: 'union type',
          body: <<~SNIP.chomp,
            type ${1:Name}
              = ${2:Variant1}
              | ${0:Variant2}
          SNIP
        ),
        Snippet.new(
          label: 'struct',
          detail: 'struct declaration',
          body: <<~SNIP.chomp,
            struct ${1:Name} = {
              ${2:field}: ${0:Type}
            }
          SNIP
        ),
        Snippet.new(
          label: 'case',
          detail: 'case expression with else fallback',
          body: <<~SNIP.chomp,
            case ${1:expr}
            in ${2:pattern} then ${3:result}
            else ${0:fallback}
            end
          SNIP
        ),
        Snippet.new(
          label: 'if',
          detail: 'if/then/else block',
          body: <<~SNIP.chomp,
            if ${1:cond} then
              ${2:then_branch}
            else
              ${0:else_branch}
            end
          SNIP
        ),
        Snippet.new(
          label: 'module',
          detail: 'module header',
          body: 'module ${1:Name} exposing (${0})',
        ),
        Snippet.new(
          label: 'import',
          detail: 'import declaration',
          body: 'import ${1:Module} exposing (${0:Name})',
        ),
        Snippet.new(
          label: 'interface',
          detail: 'interface declaration',
          body: <<~SNIP.chomp,
            interface ${1:Name}(${2:a}) with
              ${3:fn} : ${4:args} -> ${0:Return}
            end
          SNIP
        ),
        Snippet.new(
          label: 'implements',
          detail: 'interface implementation',
          body: <<~SNIP.chomp,
            implements ${1:Interface}(${2:Type}) with
              ${3:method}: ${0:fn_name}
            end
          SNIP
        ),
        Snippet.new(
          label: 'uses',
          detail: 'interop import',
          body: <<~SNIP.chomp,
            uses ${1:Module} with
              ${2:fn} : ${3:args} -> ${0:Return}
            end
          SNIP
        ),
        Snippet.new(
          label: 'lambda',
          detail: 'anonymous function',
          body: '(${1:args}) -> { ${0:body} }',
        ),
      ].freeze
    end
  end
end
