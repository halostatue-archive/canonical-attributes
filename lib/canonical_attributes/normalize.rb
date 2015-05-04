require 'active_support/concern'

# This concern adds two hooks to an ActiveRecord model:
#
# 1. #initialize_default_attribute_values. This +after_initialize+ hook method
#    should be implemented in the model, because each model knows its
#    appropriate defaults.
#
# 2. #normalize_attributes_with_defaults. This +before_validation+ hook method
#    should NOT be implemented in the model. Instead, implement
#    #normalize_attributes.
#
# === #default_attribute
#
# The private method #default_attribute has been defined to provide each
# attribute with a meaningful default.
#
#    default_attribute(key) { default_value }
#    default_attribute(key, default_value)
#
# This only sets attributes that are present in the model; it is not possible
# to set a default value for an attribute initialized from a partial model
# (<tt>Model#select(:column1)</tt> only initializes +column1+ and no other
# attributes).
#
# === #force_transform and kin
#
# Any Ruby code can be written in #normalize_attributes to transform attribute
# values, but a common mechanism for this has been provided in the private
# method #force_transform.
#
#    force_transform(transform, *attrs)
#
# This performs the provided transformation on the listed attributes. Accepts
# either a callable object (e.g., a Proc) or a Symbol.
#
# If provided a callable, the transform is called with a single argument (the
# read attribute value) and it is responsible for handling any error
# conditions, including if the read value from the attribute is nil or
# otherwise invalid.
#
# If provided a Symbol, the transform is only performed if the values are
# non-nil and respond to the method indicated by the Symbol. The method must
# not require any arguments.
#
# ==== Standard Transforms
#
# The following private transform methods have been provided to assist with the
# definition of a common transform language. The all accept one or more
# attribute name.
#
# +force_string+:: Forces string values with #to_s.
# +force_symbol+:: Forces symbol values with #to_sym.
# +force_lowercase+:: Forces lowercase values with #downcase.
# +force_uppercase+:: Forces uppercase values with #upcase.
# +force_string_or_nil+:: Forces the value to be a String or +nil+ if the value
#                         results in an empty String.
# +force_symbol_or_nil+:: Forces the value to be a Symbol or +nil+ if the value
#                         would otherwise result in an empty String.
# +force_nil_if_empty+:: Replaces #empty? values with +nil+.
# +force_json_string+:: Forces the attribute to either be +nil+ (when +nil+ or
#                       #empty?) or a String (when already a String, or through
#                       the application of #to_json).
module CanonicalAttributes::Normalize
  extend ActiveSupport::Concern

  included do
    after_initialize :initialize_default_attribute_values
    before_validation :normalize_attributes_with_defaults
  end

  # Implement this instead of overriding an ActiveRecord model’s #initialize
  # method. (Not all ways that initialize models call #initialize, such as when
  # a model is deserialized.) When used with the private method
  # #default_attribute, gives you a way to ensure that models are minimally
  # initialized before validation. The default implementation is empty.
  #
  # The #default_attribute method looks like:
  #
  def initialize_default_attribute_values
  end

  # Initialize attributes with the default values, then normalize the
  # attributes if #normalize_attributes is defined.
  def normalize_attributes_with_defaults
    initialize_default_attribute_values
    normalize_attributes if respond_to?(:normalize_attributes, true)
  end

  ##
  # :method: normalize_attributes
  #
  # This method is used to specify the normalization rules for an attribute.
  # While any mechanism can be used to normalize an attribute,
  # CanonicalAttributes::Normalize provides a number of useful transform
  # methods, documented above.

  private
  def default_attribute(key, value = nil, &block)
    if self.attributes.key?(key.to_s) and self[key].nil?
      if block
        self[key] = block.call
      else
        self[key] = value
      end
    end
  end

  def force_string(*attrs)
    force_transform :to_s, attrs
  end

  def force_symbol(*attrs)
    force_transform :to_sym, attrs
  end

  def force_lowercase(*attrs)
    force_transform :downcase, attrs
  end

  def force_uppercase(*attrs)
    force_transform :upcase, attrs
  end

  def force_string_or_nil(*attrs)
    force_string(*attrs)
    force_nil_if_empty(*attrs)
  end

  def force_symbol_or_nil(*attrs)
    force_string_or_nil(*attrs)
    force_symbol(*attrs)
  end

  def force_nil_if_empty(*attrs)
    force_transform NIL_IF_EMPTY, attrs
  end

  NIL_IF_EMPTY = ->(value) { #:nodoc:
    if value.nil? or value.empty?
      nil
    else
      value
    end
  }

  def force_json_string(*attrs)
    force_transform JSON_STRING, attrs
  end

  JSON_STRING = ->(value) { #:nodoc:
    if value.nil? or value.empty?
      nil
    elsif value.kind_of?(String)
      value
    else
      value.to_json
    end
  }

  def force_transform(transform, *attrs)
    attrs = [ attrs ].flatten
    if transform.respond_to? :call
      attrs.each do |a|
        if has_attribute?(a)
          write_attribute(a, transform.call(read_attribute(a)))
        end
      end
    else
      attrs.each do |a|
        # attribute_present? implicitly tests if the value is nil.
        if attribute_present?(a)
          if (value = read_attribute(a)) and value.respond_to?(transform)
            write_attribute(a, value.__send__(transform))
          end
        end
      end
    end
  end
end
