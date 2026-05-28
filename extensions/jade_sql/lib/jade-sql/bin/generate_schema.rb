require 'jade/lexer'
require 'jade/parsing'
require 'jade/ast'
require 'jade/formatter'
require 'jade/frontend/comment_attacher'

module JadeSql
  module SchemaGenerator
    extend self

    TYPE_MAP = {
      /\Abigint\b/ => "Int",
      /\Ainteger\b/ => "Int",
      /\Asmallint\b/ => "Int",
      /\Acharacter varying\b/ => "String",
      /\Avarchar\b/ => "String",
      /\Acharacter\b/ => "String",
      /\Achar\b/ => "String",
      /\Atext\b/ => "String",
      /\Aboolean\b/ => "Bool",
      /\Abool\b/ => "Bool",
      /\Ajsonb?\b/ => "Decode.Value",
      /\Adate\b/ => "Calendar.Date",
      /\Atimestamp\b/ => "Clock.Instant",
      /\Auuid\b/ => "Uuid",
    }.freeze

    EXTRA_IMPORTS = {
      "Calendar.Date" => "import Calendar",
      "Clock.Instant" => "import Clock",
      "Decode.Value"  => "import Decode",
      "Uuid"          => "import Sql.Uuid exposing(Uuid)",
    }.freeze

    Table = Data.define(:name, :columns, :pk_columns)
    Column = Data.define(:name, :jade_type, :nullable)

    def generate(sql, tables: nil, module_name: 'Schema')
      parsed = parse_tables(sql)
      pks = parse_pks(sql)
      parsed = parsed.map { |t| t.with(pk_columns: pks[t.name] || []) }
      parsed = filter_tables(parsed, tables) if tables
      format(emit(parsed, module_name))
    end

    # Run jade-fmt over the emitted source so the written schema.jd matches
    # what the formatter would produce — keeps the generator output stable
    # across formatter improvements and avoids spurious diffs when users
    # re-format their tree.
    def format(text)
      source = ::Jade::Source.new(uri: '<schema>', text: text)
      ::Jade::Lexer.tokenize(source)
        .then { ::Jade::Parsing.parse(it, source:) }
        .map { |(ast, comments)| ::Jade::Formatter.format(ast, comments:, source:) }
        .then do
          case it
          in ::Jade::Ok(result) then result.end_with?("\n") ? result : "#{result}\n"
          in ::Jade::Err(_) then text  # parse error — return unformatted; downstream compile will surface it
          end
        end
    end

    private

    def filter_tables(parsed, whitelist)
      missing = whitelist - parsed.map(&:name)
      raise "Unknown table(s): #{missing.join(', ')}" if missing.any?

      parsed.select { |t| whitelist.include?(t.name) }
    end

    def parse_tables(sql)
      sql
        .scan(/CREATE TABLE (?:\w+\.)?(\w+)\s*\((.*?)\);/m)
        .map { |name, body| Table[name, parse_columns(body, name), []] }
    end

    def parse_columns(body, table_name)
      body
        .split("\n")
        .map(&:strip)
        .reject(&:empty?)
        .map { |line| line.sub(/,\s*\z/, '') }
        .reject { |line| line =~ /\A(CONSTRAINT|PRIMARY KEY|UNIQUE|CHECK|FOREIGN KEY)\b/i }
        .map { |line| parse_column(line, table_name) }
    end

    def parse_column(line, table_name)
      m = line.match(/\A"?(\w+)"?\s+(.+?)(\s+NOT\s+NULL)?\s*\z/i)
      raise "Cannot parse column: #{line.inspect}" unless m

      name, type_part, not_null = m[1], m[2].strip, !m[3].nil?

      # Strip trailing modifiers we don't care about (DEFAULT ..., COLLATE ...).
      type_part = type_part.sub(/\s+DEFAULT\s+.+\z/i, '').sub(/\s+COLLATE\s+.+\z/i, '').strip

      jade_type = TYPE_MAP
        .find { |sql_pat, _| sql_pat.match?(type_part.downcase) }
        &.last

      raise "Unknown SQL type for #{table_name}.#{name}: #{type_part.inspect}" unless jade_type

      Column[name, jade_type, !not_null]
    end

    def parse_pks(sql)
      sql
        .scan(/ALTER TABLE (?:ONLY\s+)?(?:\w+\.)?(\w+)\s+ADD CONSTRAINT \w+ PRIMARY KEY \(([^)]+)\)/i)
        .to_h { |name, cols| [name, cols.split(',').map { |c| c.strip.delete('"') }] }
    end

    def emit(tables, module_name)
      [
        emit_header(tables, module_name),
        *tables.flat_map { |t| [emit_strict_cols(t), emit_maybe_cols(t), emit_row(t), emit_table_fn(t)] },
      ].join("\n\n") + "\n"
    end

    def emit_header(tables, module_name)
      exposed = tables
        .flat_map { |t| ["#{camel(t.name)}Cols", "Maybe#{camel(t.name)}Cols", "#{camel(t.name)}Row(..)", t.name] }
        .sort
        .join(", ")

      imports = ["import Sql exposing(Expr, Table, column, table)", *extra_imports_for(tables)]

      <<~JADE.strip
        module #{module_name} exposing(#{exposed})

        #{imports.join("\n")}
      JADE
    end

    def extra_imports_for(tables)
      tables
        .flat_map { |t| t.columns.map(&:jade_type) }
        .uniq
        .filter_map { |jade_type| EXTRA_IMPORTS[jade_type] }
        .sort
    end

    def emit_strict_cols(t)
      fields = t.columns
        .map { |c| "  #{c.name}: Expr(#{c.nullable ? "Maybe(#{c.jade_type})" : c.jade_type})" }
        .join(",\n")

      "struct #{camel(t.name)}Cols = {\n#{fields}\n}"
    end

    def emit_maybe_cols(t)
      fields = t.columns
        .map { |c| "  #{c.name}: Expr(Maybe(#{c.jade_type}))" }
        .join(",\n")

      "struct Maybe#{camel(t.name)}Cols = {\n#{fields}\n}"
    end

    def emit_row(t)
      fields = t.columns
        .map { |c| "  #{c.name}: #{c.nullable ? "Maybe(#{c.jade_type})" : c.jade_type}" }
        .join(",\n")

      "struct #{camel(t.name)}Row = {\n#{fields}\n}"
    end

    def emit_table_fn(t)
      strict_fields = t.columns.map { |c| "column(a, #{c.name.inspect})" }.join(", ")
      maybe_fields = t.columns.map { |c| "column(a, #{c.name.inspect})" }.join(", ")
      pk_list = "[#{t.pk_columns.map(&:inspect).join(", ")}]"

      <<~JADE.strip
        def #{t.name} -> Table(#{camel(t.name)}Cols, Maybe#{camel(t.name)}Cols)
          table(
            #{t.name.inspect},
            #{t.name.inspect},
            (a) -> { #{camel(t.name)}Cols(#{strict_fields}) },
            (a) -> { Maybe#{camel(t.name)}Cols(#{maybe_fields}) },
            #{pk_list},
          )
        end
      JADE
    end

    def camel(snake)
      snake.split('_').map(&:capitalize).join
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    warn "Usage: ruby #{$0} <schema.sql>"
    warn "       TABLES=a,b  whitelist of tables (default: all)"
    warn "       MODULE=Name override module name (default: Schema)"
    exit 1
  end

  tables = ENV['TABLES']&.split(',')&.map(&:strip)&.reject(&:empty?)
  module_name = ENV['MODULE'] || 'Schema'

  puts JadeSql::SchemaGenerator.generate(File.read(ARGV[0]), tables: tables, module_name: module_name)
end
