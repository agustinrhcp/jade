require 'spec_helper'

require_relative '../../extensions/jade_sql/lib/jade-sql/bin/generate_schema'

describe JadeSql::SchemaGenerator do
  subject(:generated) { described_class.generate(sql) }

  context 'a single table with NOT NULL and nullable columns' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.patients (
            id bigint NOT NULL,
            name character varying NOT NULL,
            balance integer
        );

        ALTER TABLE ONLY public.patients
            ADD CONSTRAINT patients_pkey PRIMARY KEY (id);
      SQL
    end

    it 'emits the module header' do
      expect(generated).to include(
        'module Schema exposing (MaybePatientsCols, PatientsCols, PatientsRow(..), patients)'
      )
    end

    it 'emits a row struct: value types, nullable wrapped in Maybe' do
      expect(generated).to include(<<~STRUCT.strip)
        struct PatientsRow = {
          id: Int,
          name: String,
          balance: Maybe(Int)
        }
      STRUCT
    end

    it 'imports Sql' do
      expect(generated).to include('import Sql exposing (Expr, Table, column, table)')
    end

    it 'does not emit Calendar/Clock/Decode imports when the schema does not use them' do
      expect(generated).not_to include('import Calendar')
      expect(generated).not_to include('import Clock')
      expect(generated).not_to include('import Decode')
    end

    it 'emits a strict struct: NOT NULL → Expr(T), nullable → Expr(Maybe(T))' do
      expect(generated).to include(<<~STRUCT.strip)
        struct PatientsCols = {
          id: Expr(Int),
          name: Expr(String),
          balance: Expr(Maybe(Int))
        }
      STRUCT
    end

    it 'emits a maybe struct: every field wrapped in Maybe' do
      expect(generated).to include(<<~STRUCT.strip)
        struct MaybePatientsCols = {
          id: Expr(Maybe(Int)),
          name: Expr(Maybe(String)),
          balance: Expr(Maybe(Int))
        }
      STRUCT
    end

    it 'emits a table function with alias = table name and pk_columns' do
      expect(generated).to include(<<~FN.strip)
        def patients -> Table(PatientsCols, MaybePatientsCols)
          table(
            "patients",
            "patients",
            (a) -> { PatientsCols(column(a, "id"), column(a, "name"), column(a, "balance")) },
            (a) -> { MaybePatientsCols(column(a, "id"), column(a, "name"), column(a, "balance")) },
            ["id"],
          )
      FN
    end
  end

  context 'type mapping' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.kitchen_sink (
            i bigint NOT NULL,
            j smallint NOT NULL,
            s text NOT NULL,
            v character varying NOT NULL,
            b boolean NOT NULL,
            j_blob jsonb NOT NULL,
            d date NOT NULL,
            ts timestamp(6) without time zone NOT NULL,
            u uuid NOT NULL
        );
      SQL
    end

    it 'maps each SQL type to the right Jade type' do
      expect(generated).to include(<<~STRUCT.strip)
        struct KitchenSinkCols = {
          i: Expr(Int),
          j: Expr(Int),
          s: Expr(String),
          v: Expr(String),
          b: Expr(Bool),
          j_blob: Expr(Decode.Value),
          d: Expr(Calendar.Date),
          ts: Expr(Clock.Instant),
          u: Expr(Uuid)
        }
      STRUCT
    end

    it 'emits the Calendar/Clock/Decode/Sql.Uuid imports when those types appear' do
      expect(generated).to include('import Calendar')
      expect(generated).to include('import Clock')
      expect(generated).to include('import Decode')
      expect(generated).to include('import Sql.Uuid exposing (Uuid)')
    end
  end

  context 'multi-column primary key' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.memberships (
            user_id bigint NOT NULL,
            group_id bigint NOT NULL
        );

        ALTER TABLE ONLY public.memberships
            ADD CONSTRAINT memberships_pkey PRIMARY KEY (user_id, group_id);
      SQL
    end

    it 'emits pk_columns as a list with all keys' do
      expect(generated).to include('["user_id", "group_id"]')
    end
  end

  context 'table without an explicit primary key constraint' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.events (
            payload jsonb NOT NULL
        );
      SQL
    end

    it 'emits pk_columns as an empty list' do
      expect(generated).to include('[]')
    end
  end

  context 'AR-emitted schema_migrations table' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.schema_migrations (
            version character varying NOT NULL
        );

        ALTER TABLE ONLY public.schema_migrations
            ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);
      SQL
    end

    it 'is generated like any other table' do
      expect(generated).to include('def schema_migrations -> Table(SchemaMigrationsCols, MaybeSchemaMigrationsCols)')
      expect(generated).to include('["version"]')
    end
  end

  context 'multiple tables in one SQL file' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.persons (
            id bigint NOT NULL,
            name character varying NOT NULL
        );

        ALTER TABLE ONLY public.persons
            ADD CONSTRAINT persons_pkey PRIMARY KEY (id);

        CREATE TABLE public.orders (
            id bigint NOT NULL,
            person_id bigint NOT NULL
        );

        ALTER TABLE ONLY public.orders
            ADD CONSTRAINT orders_pkey PRIMARY KEY (id);
      SQL
    end

    it 'emits both table functions' do
      expect(generated).to include('def persons -> Table')
      expect(generated).to include('def orders -> Table')
    end

    it 'exposes both, sorted' do
      m = generated.match(/module Schema exposing \(\s*(.+?)\s*\)\s*\nimport/m)
      expect(m).not_to be_nil
      entries = m[1].split(',').map { |e| e.strip.sub(/,\z/, '') }.reject(&:empty?)
      expect(entries).to eql %w[
        MaybeOrdersCols MaybePersonsCols OrdersCols OrdersRow(..)
        PersonsCols PersonsRow(..) orders persons
      ]
    end

    context 'with a table whitelist' do
      subject(:generated) { described_class.generate(sql, tables: ['persons']) }

      it 'only emits the listed tables' do
        expect(generated).to include('def persons -> Table')
        expect(generated).not_to include('def orders -> Table')
      end

      it 'fails loudly when a listed table is not in the SQL' do
        expect { described_class.generate(sql, tables: ['persons', 'typo']) }
          .to raise_error(/Unknown table.*typo/)
      end
    end

    context 'with a custom module name' do
      subject(:generated) { described_class.generate(sql, module_name: 'Schema.Billing') }

      it 'uses the override in the module declaration' do
        expect(generated).to include('module Schema.Billing exposing (')
      end
    end
  end

  context 'unknown SQL type' do
    let(:sql) do
      <<~SQL
        CREATE TABLE public.payments (
            amount numeric(10,2) NOT NULL
        );
      SQL
    end

    it 'fails loudly with table and column name' do
      expect { generated }.to raise_error(/payments\.amount.*numeric/)
    end
  end

  context 'ignores AR boilerplate' do
    let(:sql) do
      <<~SQL
        SET statement_timeout = 0;
        SET lock_timeout = 0;

        CREATE TABLE public.persons (
            id bigint NOT NULL
        );

        CREATE SEQUENCE public.persons_id_seq AS integer;
        ALTER SEQUENCE public.persons_id_seq OWNED BY public.persons.id;
        ALTER TABLE ONLY public.persons ALTER COLUMN id SET DEFAULT nextval('public.persons_id_seq'::regclass);

        ALTER TABLE ONLY public.persons
            ADD CONSTRAINT persons_pkey PRIMARY KEY (id);

        CREATE INDEX index_persons_on_name ON public.persons USING btree (id);
      SQL
    end

    it 'still parses the persons table cleanly' do
      expect(generated).to include('def persons -> Table')
      expect(generated).to include('["id"]')
    end
  end
end
