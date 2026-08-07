require 'spec_helper'

require 'rake'
require 'tmpdir'
require 'fileutils'

$LOAD_PATH.unshift File.expand_path('../../extensions/jade_sql/lib', __dir__)

describe 'jade:schema rake task' do
  let(:rake_file) do
    File.expand_path('../../extensions/jade_sql/lib/jade-sql/tasks.rake', __dir__)
  end

  let(:sql) do
    <<~SQL
      CREATE TABLE public.patients (
          id bigint NOT NULL,
          name character varying NOT NULL
      );

      ALTER TABLE ONLY public.patients
          ADD CONSTRAINT patients_pkey PRIMARY KEY (id);
    SQL
  end

  around do |example|
    Dir.mktmpdir do |tmp|
      Dir.chdir(tmp) do
        rake = Rake::Application.new
        Rake.application = rake
        load rake_file
        @rake = rake
        original_stdout = $stdout
        $stdout = File.open(File::NULL, 'w')
        begin
          example.run
        ensure
          $stdout = original_stdout
        end
      end
    end
  ensure
    Rake.application = Rake::Application.new
  end

  it 'reads db/structure.sql and writes app/jade/schema.jd by default' do
    FileUtils.mkdir_p('db')
    File.write('db/structure.sql', sql)

    @rake['jade:schema'].invoke

    expect(File).to exist('app/jade/schema.jd')
    expect(File.read('app/jade/schema.jd'))
      .to include('def patients -> Table(PatientsCols, MaybePatientsCols)')
  end

  it 'honours INPUT and OUTPUT env vars' do
    File.write('custom.sql', sql)
    ENV['INPUT']  = 'custom.sql'
    ENV['OUTPUT'] = 'out/schema.jd'

    @rake['jade:schema'].invoke

    expect(File).to exist('out/schema.jd')
  ensure
    ENV.delete('INPUT')
    ENV.delete('OUTPUT')
  end

  it 'honours TABLES and MODULE env vars' do
    multi_table_sql = <<~SQL
      CREATE TABLE public.persons (
          id bigint NOT NULL
      );

      CREATE TABLE public.orders (
          id bigint NOT NULL
      );
    SQL

    FileUtils.mkdir_p('db')
    File.write('db/structure.sql', multi_table_sql)

    ENV['TABLES'] = 'persons'
    ENV['MODULE'] = 'Schema.Persons'

    @rake['jade:schema'].invoke

    content = File.read('app/jade/schema.jd')
    expect(content).to include('module Schema.Persons exposing (')
    expect(content).to include('def persons -> Table')
    expect(content).not_to include('def orders -> Table')
  ensure
    ENV.delete('TABLES')
    ENV.delete('MODULE')
  end
end
