require 'date'
require 'jade/tasks'

# Opt-in runtime: requires ActiveRecord. The Jade-side Sql.Run module
# declares ports against this. Loaded only when the user explicitly does
# `require 'jade-sql/runtime'`.
module JadeSql
  module Runtime
    extend Jade::Port

    task :port_execute_count do |t, pair|
      sql, params = pair._1, pair._2
      conn = ::ActiveRecord::Base.connection
      t.ok(conn.exec_update(adapt_sql(sql, conn), "Jade", params))
    rescue ::ActiveRecord::StatementInvalid => e
      t.err(JadeSql::SqlErrors.db_error(e.message))
    end

    task :port_execute_one do |t, pair|
      sql, params = pair._1, pair._2
      conn = ::ActiveRecord::Base.connection
      rows = conn.exec_query(adapt_sql(sql, conn), "Jade", params).to_a
      case rows.length
      when 0 then t.err(JadeSql::SqlErrors.not_found)
      when 1 then t.ok(coerce_row(rows.first))
      else        t.err(JadeSql::SqlErrors.not_unique)
      end
    rescue ::ActiveRecord::StatementInvalid => e
      t.err(JadeSql::SqlErrors.db_error(e.message))
    end

    task :port_execute_many do |t, pair|
      sql, params = pair._1, pair._2
      conn = ::ActiveRecord::Base.connection
      rows = conn.exec_query(adapt_sql(sql, conn), "Jade", params).to_a
      t.ok(rows.map { |row| coerce_row(row) })
    rescue ::ActiveRecord::StatementInvalid => e
      t.err(JadeSql::SqlErrors.db_error(e.message))
    end

    # AR's PG adapter returns ::Date / ::Time for date/timestamp columns;
    # Calendar.Date / Clock.Instant decoders expect ISO strings. Coerce
    # at the boundary so callers don't sprinkle text_cast in every SELECT.
    def self.coerce_row(row)
      row.transform_values do |v|
        case v
        when ::Date             then v.iso8601
        when ::Time, ::DateTime then v.iso8601
        else v
        end
      end
    end

    # Sql renders `?` placeholders uniformly. AR's exec_query/exec_update
    # path on the PG adapter expects `$1, $2, …` — there is no `?`-to-`$n`
    # rewrite at that layer. SQLite and MySQL accept `?` directly, so this
    # is a no-op there. Naive substitution; doesn't dodge `?` inside string
    # literals — fix when someone hits it.
    def self.adapt_sql(sql, conn)
      return sql unless conn.adapter_name =~ /postgres/i

      i = 0
      sql.gsub("?") { i += 1; "$#{i}" }
    end
  end
end
