require 'jade/result'

module Jade
  module Diagnostics
    Label = Data.define(:source, :span, :message)
    Annotation = Data.define(:kind, :message)

    Diagnostic = Data.define(:severity, :message, :primary, :secondary, :annotations) do
      def self.error(message, primary:, secondary: [], annotations: [])
        new(severity: :error, message:, primary:, secondary:, annotations:)
      end

      def self.warning(message, primary:, secondary: [], annotations: [])
        new(severity: :warning, message:, primary:, secondary:, annotations:)
      end

      def error?
        severity == :error
      end

      def annotate(kind, text)
        with(annotations: annotations + [Annotation[kind, text]])
      end
    end

    List = Data.define(:items) do
      def self.empty
        new(items: [])
      end

      def add(diagnostic)
        with(items: items + [diagnostic])
      end

      def error(message, source:, span:, label: nil, secondary: [], annotations: [])
        add(Diagnostic.error(
          message,
          primary: Label[source, span, label],
          secondary:,
          annotations:,
        ))
      end

      def note(text)
        update_last { _1.annotate(:note, text) }
      end

      def help(text)
        update_last { _1.annotate(:help, text) }
      end

      def merge(other)
        with(items: items + other.items)
      end

      def any_errors?
        items.any?(&:error?)
      end

      def empty?
        items.empty?
      end

      def to_result(value)
        any_errors? ? Err.new(self) : Ok.new(value)
      end

      private

      def update_last(&block)
        return self if items.empty?

        with(items: items[0...-1] + [block.call(items.last)])
      end
    end
  end
end
