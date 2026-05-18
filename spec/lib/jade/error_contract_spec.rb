require 'spec_helper'

require 'jade'
require 'jade/module_loader'

Dir[File.expand_path('../../../../lib/jade/**/error/*.rb', __FILE__)].each do |f|
  require_relative f
end
require 'jade/parsing/error'

module Jade
  describe 'Error contract' do
    # Snapshot of leaf errors still missing `#label`; shrink as you polish.
    LABEL_DEBT = %w[
      Jade::Frontend::ForwardDeclaration::Error::BadImport
      Jade::Frontend::ForwardDeclaration::Error::ExposedTypeNotFound
      Jade::Frontend::ForwardDeclaration::Error::ExposedValueNotFound
      Jade::Frontend::ForwardDeclaration::Error::ModuleNotFound
      Jade::Frontend::ForwardDeclaration::Error::PrivateTypeExpansion
      Jade::Frontend::ForwardDeclaration::Error::TypeNotLowerable
      Jade::Frontend::ForwardDeclaration::Error::UnknownExtendsInterface
      Jade::Frontend::SemanticAnalysis::Error::CircularExtends
      Jade::Frontend::SemanticAnalysis::Error::DuplicateRecordField
      Jade::Frontend::SemanticAnalysis::Error::MissingExposingClause
      Jade::Frontend::SemanticAnalysis::Error::MissingExtendsImplementation
      Jade::Frontend::SemanticAnalysis::Error::MissingImplementationFunction
      Jade::Frontend::SemanticAnalysis::Error::NestedTaskPort
      Jade::Frontend::SemanticAnalysis::Error::OrphanImplementation
      Jade::Frontend::SemanticAnalysis::Error::TypeParamRequired
      Jade::Frontend::SemanticAnalysis::Error::UnboundTypeVariable
      Jade::Frontend::SemanticAnalysis::Error::UnknownImplementationFunction
      Jade::Frontend::SymbolResolution::Error::DuplicateField
      Jade::Frontend::SymbolResolution::Error::KwargsOnNonConstructor
      Jade::Frontend::SymbolResolution::Error::MissingField
      Jade::Frontend::SymbolResolution::Error::UnknownField
      Jade::Frontend::TypeChecking::Error::DerivationFailed
      Jade::Frontend::TypeChecking::Error::MissingImplementation
      Jade::Frontend::TypeChecking::Error::UnresolvedConstraint
      Jade::Parsing::EOFError
      Jade::Parsing::InvalidOperatorError
    ].freeze

    def leaves
      descendants = ObjectSpace.each_object(Class).select { |k| k < Jade::Error }
      descendants.reject { |k| descendants.any? { _1 < k } }
    end

    def missing_label
      leaves
        .reject { |k| k.instance_method(:label).owner != Jade::Error }
        .map(&:name)
        .sort
    end

    def missing_message
      leaves
        .reject { |k| k.instance_method(:message).owner != Jade::Error }
        .map(&:name)
        .sort
    end

    it 'every leaf error class overrides #message somewhere up its ancestor chain' do
      expect(missing_message).to be_empty
    end

    it 'every new leaf error class overrides #label (LABEL_DEBT lists the existing exceptions)' do
      missing = missing_label
      new_offenders = missing - LABEL_DEBT
      stale = LABEL_DEBT - missing

      expect(new_offenders).to be_empty,
        "These error classes need a `label` method:\n  #{new_offenders.join("\n  ")}"
      expect(stale).to be_empty,
        "These error classes now have `label` — remove from LABEL_DEBT:\n  #{stale.join("\n  ")}"
    end
  end
end
