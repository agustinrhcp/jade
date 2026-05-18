require 'spec_helper'

require 'jade'
require 'jade/runtime'
require 'jade/codegen/inlines'

Jade::Runtime.boot!

module Jade
  describe 'stdlib intrinsic inline coverage' do
    Jade::Runtime::INTRINSICS.each do |qualified_name, runtime_block|
      # Derived stdlib fns (registered with `body:` and no `&block`) have a
      # nil runtime block. Their codegen comes from the DerivedFunction IR,
      # not from an inline template — out of scope for this coverage check.
      next if runtime_block.nil?

      it "#{qualified_name} is either inlined or explicitly skipped" do
        inlined = !Codegen::Inlines.for(qualified_name).nil?
        skipped = Codegen::Inlines.expected_to_skip?(qualified_name)

        expect(inlined || skipped).to be(true),
          "Stdlib intrinsic #{qualified_name} has a runtime block but no entry " \
          "in INLINES and is not in NO_INLINE. Either add an inline template " \
          "to lib/jade/codegen/inlines.rb#INLINES, or add the qualified name " \
          "to NO_INLINE in the same file with a reason."
      end
    end
  end
end
