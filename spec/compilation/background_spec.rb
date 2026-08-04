require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Task.background' do
    include_context 'with test compiler'

    module TestMailer
      extend Jade::Port

      SENT = []

      task :send_welcome do |t, id|
        SENT << id
        t.ok(1)
      end
    end

    before { TestMailer::SENT.clear }

    let(:port) do
      <<~JADE
        uses Jade::TestMailer with
          send_welcome : String -> Task(Int, Never)
        end
      JADE
    end

    context 'a direct port call' do
      let(:source) do
        <<~JADE
          module Backgrounding exposing (go)

          #{port}

          def go(id: String) -> Task(String, String)
            send_welcome(id) |> Task.background
          end
        JADE
      end

      it 'compiles, and enqueues through the adapter' do
        test_compiler.require('backgrounding', source)

        expect(Backgrounding::Internal.go('u-1').run).to be_ok(/\Ainline:/)
      end

      it 'runs the port, since the default adapter is inline' do
        test_compiler.require('backgrounding', source)
        Backgrounding::Internal.go('u-1').run

        expect(TestMailer::SENT).to eq(['u-1'])
      end

      it 'hands a configured adapter the port name and its encoded args' do
        recorder = Class.new do
          attr_reader :enqueued

          def initialize = @enqueued = []

          def enqueue(task_def, args, options)
            @enqueued << [task_def.name, args, options]
            'job-42'
          end
        end.new

        Jade::Background.adapter = recorder
        test_compiler.require('backgrounding', source)
        result = Backgrounding::Internal.go('u-1').run

        expect(result).to be_ok('job-42')
        expect(recorder.enqueued).to eq([['send_welcome', ['u-1'], {}]])
        expect(TestMailer::SENT).to be_empty
      ensure
        Jade::Background.adapter = Jade::Background::Inline
      end
    end

    context 'a composed task' do
      let(:source) do
        <<~JADE
          module Backgrounding exposing (go)

          #{port}

          def go(id: String) -> Task(String, String)
            send_welcome(id)
              |> Task.map((n) -> { n })
              |> Task.background
          end
        JADE
      end

      it 'is rejected at compile time' do
        expect { test_compiler.require('backgrounding', source) }
          .to raise_error(/port call/)
      end
    end

    context 'with options' do
      let(:recorder) do
        Class.new do
          attr_reader :enqueued

          def initialize = @enqueued = []

          def enqueue(_task_def, _args, options)
            @enqueued << options
            'job-42'
          end
        end.new
      end

      let(:source) do
        <<~JADE
          module Backgrounding exposing (go)

          import Decode exposing (Value)
          import Encode exposing (Encodable)


          #{port}

          type Schedule
            = Now
            | In(Int)


          struct Options = {
            queue: String,
            schedule: Schedule
          }


          def encode_schedule(s: Schedule) -> Value
            case s
            in Now then Encode.variant("now", [])
            in In(millis) then Encode.variant("in", [Encode.int(millis)])
            end
          end


          implements Encodable(Schedule) with
            encoder: encode_schedule
          end


          def go(id: String) -> Task(String, String)
            send_welcome(id)
              |> Task.background_with(Options(queue: "mailers", schedule: In(30000)))
          end
        JADE
      end

      around do |example|
        Jade::Background.adapter = recorder
        example.run
        Jade::Background.adapter = Jade::Background::Inline
      end

      it 'hands the adapter the options in their encoded form' do
        test_compiler.require('backgrounding', source)
        result = Backgrounding::Internal.go('u-1').run

        expect(result).to be_ok('job-42')
        expect(recorder.enqueued)
          .to eq([{ 'queue' => 'mailers', 'schedule' => ['in', 30000] }])
      end

      it 'does not run the port' do
        test_compiler.require('backgrounding', source)
        Backgrounding::Internal.go('u-1').run

        expect(TestMailer::SENT).to be_empty
      end
    end

    context 'options that cannot cross a process boundary' do
      let(:source) do
        <<~JADE
          module Backgrounding exposing (go)

          #{port}

          struct Options = { on_done: Int -> Int }


          def go(id: String) -> Task(String, String)
            send_welcome(id) |> Task.background_with(Options(on_done: (n) -> { n }))
          end
        JADE
      end

      it 'is rejected at compile time, since a function has no Encodable' do
        expect { test_compiler.require('backgrounding', source) }
          .to raise_error(/Encodable/i)
      end
    end

    context 'a composed task with options' do
      let(:source) do
        <<~JADE
          module Backgrounding exposing (go)

          #{port}

          struct Options = { queue: String }


          def go(id: String) -> Task(String, String)
            send_welcome(id)
              |> Task.map((n) -> { n })
              |> Task.background_with(Options(queue: "mailers"))
          end
        JADE
      end

      it 'is rejected at compile time, same as background' do
        expect { test_compiler.require('backgrounding', source) }
          .to raise_error(/port call/)
      end
    end
  end
end
