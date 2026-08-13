module Jade
  module Symbol
    InteropFunction = Data.define(
      :module_name,
      :name,
      :params,
      :return_type,
      :interop_module_name,
      :constraints, # [[iface_qname, var_name]] — implicit Decodable on the
                    # return arms' vars, Encodable on the params'
      :decoders, # { ok: impl_or_pass_or_dict, err: ... } | nil
      :encoders, # [impl_or_pass_or_dict], one per param | nil
      :capabilities, # ["Sql.read", ...] from `as` tags; [] means untagged,
                     # which reads as the port's own qualified name rather
                     # than as no capability at all.
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
