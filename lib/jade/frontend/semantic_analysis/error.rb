require 'jade/error'

require 'jade/frontend/semantic_analysis/error/constructor_pattern_arity_mismatch'
require 'jade/frontend/semantic_analysis/error/duplicate_function_declaration'
require 'jade/frontend/semantic_analysis/error/duplicate_record_field'
require 'jade/frontend/semantic_analysis/error/missing_exposing_clause'
require 'jade/frontend/semantic_analysis/error/circular_extends'
require 'jade/frontend/semantic_analysis/error/missing_extends_implementation'
require 'jade/frontend/semantic_analysis/error/missing_implementation_function'
require 'jade/frontend/semantic_analysis/error/orphan_implementation'
require 'jade/frontend/semantic_analysis/error/shadowing_error'
require 'jade/frontend/semantic_analysis/error/type_args_mismatch'
require 'jade/frontend/semantic_analysis/error/unbound_type_variable'
require 'jade/frontend/semantic_analysis/error/undefined_variable'
require 'jade/frontend/semantic_analysis/error/unknown_implementation_function'

module Jade
  module Frontend
    module SemanticAnalysis
      module Error
      end
    end
  end
end
