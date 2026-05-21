require 'jade-sql/bin/generate_schema'

namespace :jade do
  desc "Generate schema.jd from db/structure.sql (INPUT, OUTPUT, TABLES, MODULE)"
  task :schema do
    input       = ENV['INPUT']  || 'db/structure.sql'
    output      = ENV['OUTPUT'] || 'app/jade/schema.jd'
    tables      = ENV['TABLES']&.split(',')&.map(&:strip)&.reject(&:empty?)
    module_name = ENV['MODULE'] || 'Schema'

    FileUtils.mkdir_p(File.dirname(output))
    File.write(
      output,
      JadeSql::SchemaGenerator.generate(File.read(input), tables: tables, module_name: module_name),
    )

    puts "wrote #{output}"
  end
end
