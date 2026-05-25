require 'jade/error'

require 'jade/frontend/semantic_analysis/error/circular_extends'
require 'jade/frontend/semantic_analysis/error/constant_not_callable'
require 'jade/frontend/semantic_analysis/error/constructor_not_found'
require 'jade/frontend/semantic_analysis/error/constructor_pattern_arity_mismatch'
require 'jade/frontend/semantic_analysis/error/duplicate_field'
require 'jade/frontend/semantic_analysis/error/duplicate_function_declaration'
require 'jade/frontend/semantic_analysis/error/duplicate_record_field'
require 'jade/frontend/semantic_analysis/error/invalid_list_rest_pattern'
require 'jade/frontend/semantic_analysis/error/kwargs_on_non_constructor'
require 'jade/frontend/semantic_analysis/error/missing_exposing_clause'
require 'jade/frontend/semantic_analysis/error/missing_extends_implementation'
require 'jade/frontend/semantic_analysis/error/missing_field'
require 'jade/frontend/semantic_analysis/error/missing_implementation_function'
require 'jade/frontend/semantic_analysis/error/module_not_found'
require 'jade/frontend/semantic_analysis/error/nested_task_port'
require 'jade/frontend/semantic_analysis/error/non_task_port'
require 'jade/frontend/semantic_analysis/error/orphan_implementation'
require 'jade/frontend/semantic_analysis/error/predicate_must_return_bool'
require 'jade/frontend/semantic_analysis/error/predicate_name_not_allowed'
require 'jade/frontend/semantic_analysis/error/shadowing_error'
require 'jade/frontend/semantic_analysis/error/type_args_mismatch'
require 'jade/frontend/semantic_analysis/error/type_param_required'
require 'jade/frontend/semantic_analysis/error/unbound_type_variable'
require 'jade/frontend/semantic_analysis/error/undefined_variable'
require 'jade/frontend/semantic_analysis/error/unknown_field'
require 'jade/frontend/semantic_analysis/error/unknown_implementation_function'
require 'jade/frontend/semantic_analysis/error/unused_interface_type_param'
require 'jade/frontend/semantic_analysis/error/value_not_exposed'
require 'jade/frontend/semantic_analysis/error/variable_not_found'

module Jade
  module Frontend
    module SemanticAnalysis
      module Error
      end
    end
  end
end
