module Jade
  module Symbol
    InteropFunction = Data.define(
      :module_name,
      :name,
      :params,
      :return_type,
      :interop_module_name,
      :constraints, # [[iface_qname, var_name]] — implicit Decodable on var arms
      :decoders, # { ok: impl_or_pass_or_dict, err: ... } | nil
    ) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end
    end

    InteropFunction::PASS = :pass
    InteropFunction::Dict = Data.define(:constraint_index)
  end
end
