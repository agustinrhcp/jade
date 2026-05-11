module Jade
  module Symbol
    InteropFunction = Data.define(
      :module_name,
      :name,
      :params,
      :return_type,
      :interop_module_name,
      :decoders, # { ok: impl_or_pass, err: impl_or_pass } | nil
    ) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end

    InteropFunction::PASS = :pass
  end
end
