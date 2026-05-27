require 'spec_helper'

require 'jade'
require 'jade/module_loader'
require 'jade/tasks'
require 'jade/tasks/rspec'
require_relative '../../extensions/jade_sql/lib/jade-sql'

module JadeSql
  module Runtime
    extend Jade::Port unless respond_to?(:task)

    task(:port_execute_many) { |t| t.err(JadeSql::SqlErrors.db_error("unstubbed")) }
  end
end

module Jade
  describe 'Sql.in' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module App exposing (in_some_ids)

        import Sql exposing (Expr, column, in)


        def in_some_ids(ids: List(Int)) -> Expr(Bool)
          column("p", "id") |> in(ids)
      JADE
    end

    before { test_compiler.require('app', source) }

    it 'renders col IN (?, ?, ?) and threads params' do
      e = App::Internal.in_some_ids([1, 2, 3])
      expect(e.sql).to eql 'p.id IN (?, ?, ?)'
      expect(e.params).to eql [1, 2, 3]
    end

    it 'renders FALSE for an empty list (PG rejects IN ())' do
      e = App::Internal.in_some_ids([])
      expect(e.sql).to eql 'FALSE'
      expect(e.params).to eql []
    end
  end

  describe 'Sql.Loader' do
    include_context 'with test compiler'

    describe 'group_by + lookup_or_empty' do
      let(:source) do
        <<~JADE
          module App exposing (group, lookup)

          import Sql.Loader exposing (group_by, lookup_or_empty)
          import Dict exposing (Dict)


          struct Order = {
            id: Int,
            patient_id: Int
          }


          def group(orders: List(Order)) -> Dict(Int, List(Order))
            group_by(orders, (o) -> { o.patient_id })


          def lookup(grouped: Dict(Int, List(Order)), id: Int) -> List(Order)
            lookup_or_empty(grouped, id)
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'groups items by key' do
        orders = [
          App::Order[1, 100],
          App::Order[2, 100],
          App::Order[3, 200],
        ]
        grouped = App::Internal.group(orders)
        expect(App::Internal.lookup(grouped, 100).length).to eql 2
        expect(App::Internal.lookup(grouped, 200).length).to eql 1
      end

      it 'returns [] for missing keys' do
        orders = [App::Order[1, 100]]
        grouped = App::Internal.group(orders)
        expect(App::Internal.lookup(grouped, 999)).to eql []
      end
    end

    describe 'multi-assoc bundling (Patient + Orders + Addresses)' do
      let(:source) do
        <<~JADE
          module App exposing (bundle)

          import Sql.Loader exposing (group_by, lookup_or_empty)
          import Dict exposing (Dict)


          struct Patient = {
            id: Int,
            name: String
          }


          struct Order = {
            id: Int,
            patient_id: Int,
            total: Int
          }


          struct Address = {
            id: Int,
            patient_id: Int,
            city: String
          }


          struct PatientView = {
            patient: Patient,
            orders: List(Order),
            addresses: List(Address)
          }


          def bundle(
            patients: List(Patient),
            orders: List(Order),
            addresses: List(Address),
          ) -> List(PatientView)
            orders_by_pid = group_by(orders, (o) -> { o.patient_id })
            addrs_by_pid = group_by(addresses, (a) -> { a.patient_id })

            List.map(
              patients,
              (p) -> { PatientView(
                p,
                lookup_or_empty(orders_by_pid, p.id),
                lookup_or_empty(addrs_by_pid, p.id),
              ) },
            )
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'zips primaries with both assoc lists; missing keys get []' do
        patients = [App::Patient[1, "Alice"], App::Patient[2, "Bob"]]
        orders   = [App::Order[10, 1, 100], App::Order[11, 1, 200], App::Order[12, 2, 50]]
        addrs    = [App::Address[20, 1, "Paris"]]

        result = App::Internal.bundle(patients, orders, addrs)

        expect(result[0].patient.name).to eql "Alice"
        expect(result[0].orders.length).to eql 2
        expect(result[0].addresses.length).to eql 1
        expect(result[0].addresses.first.city).to eql "Paris"

        expect(result[1].patient.name).to eql "Bob"
        expect(result[1].orders.length).to eql 1
        expect(result[1].addresses).to eql []
      end
    end

    describe 'nested-assoc bundling (Patient -> Orders -> LineItems)' do
      let(:source) do
        <<~JADE
          module App exposing (bundle)

          import Sql.Loader exposing (group_by, lookup_or_empty)
          import Dict exposing (Dict)


          struct Patient = { id: Int }


          struct Order = {
            id: Int,
            patient_id: Int
          }


          struct LineItem = {
            id: Int,
            order_id: Int,
            sku: String
          }


          struct OrderWithItems = {
            order: Order,
            items: List(LineItem)
          }


          struct PatientView = {
            patient: Patient,
            orders: List(OrderWithItems)
          }


          def with_items(
            orders: List(Order),
            items: List(LineItem),
          ) -> List(OrderWithItems)
            items_by_oid = group_by(items, (i) -> { i.order_id })

            List.map(
              orders,
              (o) -> { OrderWithItems(o, lookup_or_empty(items_by_oid, o.id)) },
            )


          def bundle(
            patients: List(Patient),
            orders: List(Order),
            items: List(LineItem),
          ) -> List(PatientView)
            orders_with_items = with_items(orders, items)
            owi_by_pid = group_by(orders_with_items, (owi) -> { owi.order.patient_id })

            List.map(
              patients,
              (p) -> { PatientView(p, lookup_or_empty(owi_by_pid, p.id)) },
            )
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'composes loader primitives across nesting levels' do
        patients = [App::Patient[1], App::Patient[2]]
        orders   = [App::Order[10, 1], App::Order[11, 1], App::Order[12, 2]]
        items    = [App::LineItem[100, 10, "a"], App::LineItem[101, 10, "b"], App::LineItem[102, 12, "c"]]

        result = App::Internal.bundle(patients, orders, items)

        expect(result[0].orders.length).to eql 2
        expect(result[0].orders[0].items.length).to eql 2
        expect(result[0].orders[1].items).to eql []
        expect(result[1].orders.first.items.first.sku).to eql "c"
      end
    end
  end
end
