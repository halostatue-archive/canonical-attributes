require 'active_support/concern'

# This concern adds three class methods to help provide restricted value
# attributes, similar to +simple_enum+ and other enumeration gems.
#
# The CanonicalAttributes::Restricted concern adds a class method to an
# ActiveRecord-based model allowing for the designation of attributes as having
# a restricted set of values, similar to +simple_enum+ and other enumeration
# gems.
#
# == Synopsis
#
#   class Lamp < ActiveRecord::Base
#     restricted :power, %w(on off)
#   end
#
# Specifying +restricted+ in its simplest state like the above adds several
# pieces of functionality to the +Lamp+ class:
#
# - It creates two scopes, <tt>Lamp.power_on</tt> and <tt>Lamp.power_off</tt>,
#   that search records with the appropriate value in +power+.
# - It creates two query functions, <tt>Lamp#power_on?</tt> and
#   <tt>Lamp#power_off?</tt>, indicating the current value in +power+.
# - It creates two assignment functions, <tt>Lamp#power_on!</tt> and
#   <tt>Lamp#power_off!</tt> that set +power+ to the appropriate value.
# - It creates a validation for the possible values of +power+.
#
#     validates :power, presence: { allow_blank: false },
#       inclusion: { in: %w(on off), message: '%{value} is not a valid power' }
#
# Note that the list and its items are also frozen so that the list of
# permitted values cannot change while the program is running.
#
# Each of these can be customized with option parameters.
#
#   restricted attribute, list, options
#
# === Default Prefix
#
# The option parameter +prefix+ controls the prefix across all generated
# methods. The default prefix is <tt><em>attribute</em></tt>. If +prefix+ is
# +nil+, generated methods will have no prefix (this is *not* recommended as
# value names may mask other methods or attributes). If +prefix+ is any other
# value, it will be used as the prefix.
#
#   restricted :power, %w(on off), prefix: 'hydro'
#
# This will create <tt>Lamp.hydro_on</tt>, <tt>Lamp.hydro_off</tt>,
# <tt>Lamp#hydro_on?</tt>, <tt>Lamp#hydro_off?</tt>, <tt>Lamp#hydro_on!</tt>,
# and <tt>Lamp#hydro_off!</tt>.
#
# === Scopes
#
# +scope+ controls the generation of scopes.
#
# +true+::  Scopes are generated with the default prefix. This is the default
#           behaviour if +scope+ is not specified.
# +false+:: Disable scope generation.
# +nil+::   Scopes are generated without a prefix. This would result in scopes
#           of <tt>Lamp.on</tt> and <tt>Lamp.off</tt>. This option is not
#           recommended because it may hide other class methods.
# <tt><em>prefix</em></tt>:: Scopes are generated with a custom prefix.
#
# - <tt>scope: false</tt> prevents the generation of scopes.
# - <tt>scope: nil</tt> generates bare scopes, <tt>Model.<em>value</em></tt>.
# - <tt>scope: <em>prefix</em></tt> generates scopes with a custom prefix,
#   <tt>Model.<em>prefix</em>_<em>value</em></tt>.
#
# === Query Functions
#
# +query+ controls the generation of query functions.
#
# +true+::  Query functions are generated with the default prefix. This is the
#           default behaviour if +query+ is not specified.
# +false+:: Disable query function generation.
# +nil+::   Query functions are generated without a prefix. This would result
#           in query of <tt>Lamp#on?</tt> and <tt>Lamp#off?</tt>.
# <tt><em>prefix</em></tt>:: Query functions are generated with a custom
#                            prefix.
#
# === Assignment Functions
#
# +assign+ controls the generation of assignment functions.
#
# +true+::  Assignment functions are generated with the default prefix. This is
#           the default behaviour if +assignment+ is not specified.
# +false+:: Disable assignment function generation.
# +nil+::   Assignment functions are generated without a prefix. This would
#           result in assignment functions of <tt>Lamp#on!</tt> and
#           <tt>Lamp#off!</tt>.
# <tt><em>prefix</em></tt>:: Assignment functions are generated with a custom
#                            prefix.
#
# === Value Transforms
#
# +transform+ creates an alternative version of <tt>#<em>attribute</em>=</tt>
# that ensures that the assigned value matches the values in the restricted
# value list. +transform+ is also used to ensure that generated query functions
# convert properly, but have no effect on scope generation.
#
# The value to +transform+ may be:
#
# - A callable object (such as a Proc) that performs a transform on the value.
#   The callable must accept one parameter (the value being transformed) and is
#   responsible for handling nullable values on its own.
# - A symbol, or array of symbols, representing methods to be called on the
#   received value. An array of symbols, if provided, has the effect of
#   chaining method calls. This handles nullable values silently (if the value
#   or a result is nullable, only the resulting +nil+ value is returned).
#
# The following examples are equivalent:
#
#   restricted :power, %w(on off), transform: ->(v) { v && v.to_s.downcase }
#   restricted :power, %w(on off), transform: [ :to_s, :downcase ]
#
# In either case, assigning to <tt>Lamp#power=</tt> will convert the input
# value to a string and then force it to be lowercase before the value is put
# in the model.
#
# === Default Value
#
# If +default+ is provided, <tt><em>attribute</em></tt> will be set to this
# value by default through the use of +after_initialization+ and
# +before_validation+ hooks.
#
# === Validations
#
# +validate+ accepts the following values to control validation generation:
#
# - If +true+ (the default) or <tt>{ presence: true }</tt>, validations will be
#   generated for presence (disallowing blank values) and set inclusion.
# - If <tt>{ presence: false }</tt>, validation will be generated for set
#   inclusion, but blank values will be permitted.
# - If +false+ or +nil+, validations will not be generated.
#
# == Helper Methods
#
# CanonicalAttributes::Restricted also provides two helper methods for working
# with lists.
#
# === +immutable_values+
#
#   immutable_values(list)
#
# This method will freeze the values in +list+ and then freeze the list itself.
# This is mostly useful when the set of permitted values can be grouped into
# smaller sets.
#
#    class User < ActiveRecord::Base
#      ACTIVE_USERS   = immutable_values(%w(active suspended))
#      INACTIVE_USERS = immutable_values(%w(deleted))
#      USER_STATES    = ACTIVE_USERS + INACTIVE_USERS
#      restricted :status, USER_STATES
#    end
#
# === +mutable_copy+
#
#   mutable_copy(list)
#
# This method returns a mutable copy of the list.
module CanonicalAttributes::Restricted
  extend ActiveSupport::Concern

  # The class methods for CanonicalAttributes::Restricted.
  module ClassMethods #:nodoc:
    # This method freezes the values in the +list+ and then freezes the list.
    def immutable_values(list)
      list.each(&:freeze).freeze
    end

    # Returns a copy of +list+ with duplicated (and unfrozen) values.
    def mutable_copy(list)
      list.map(&:dup)
    end

    # This method restricts the values for an attribute to the provided
    # list (currently an array of strings or symbols).
    #
    # - The +list+ is iterated over, freezes the values, and then freezes
    #   the +list+.
    #
    # - Validations against the attribute will be created specifying
    #   inclusion in the set of values. This can be controlled by the
    #   <tt>:presence => false</tt> value. If this is not specified, a
    #   +true+ value is assumed.
    #   - When +:presence+ is +true+, the attribute validation will include
    #     <tt>:presence => true</tt> and have <tt>:inclusion => { :in =>
    #     list }</tt>.
    #   - When +:presence+ is +false+, the attribute validation will have
    #     <tt>:inclusion => { :in => [ "" ] + list }</tt>.
    def restricted(attribute, list, options = {})
      prefix = options.fetch(:prefix, attribute)
      query = option_(options.fetch(:query, true), prefix)
      scope = option_(options.fetch(:scope, true), prefix)
      assign = option_(options.fetch(:assign, true), prefix)

      if options[:transform]
        xform = options[:transform] || ->(v) { v }
        xproc = if xform.respond_to? :call
                  xform
                else
                  xform = Array(xform)
                  ->(v) {
                    v && xform.inject(v) { |v, m| v && v.__send__(m) }
                  }
                end

        define_method("#{attribute}=".to_sym) do |value|
          self[attribute] = xproc.call(value || default)
        end
      else
        xproc = ->(v) { v }
      end

      if options.key? :default
        default = options[:default]
        default_name = :"#{attribute}_restricted_default"

        define_method default_name do
          if self.attributes.key?(attribute) && self[key].nil?
            self[key] = xproc.call(default)
          end
        end

        after_initialize default_name
        before_validation default_name
      end

      list.each do |value|
        value.freeze

        scope(:"#{scope}#{value}", ->{ where(attribute => value) }) if scope

        if query
          define_method(:"#{query}#{value}?") do
            xproc.call(self[attribute]) == value
          end
        end

        if assign
          define_method(:"#{assign}#{value}!") do
            if new_record?
              self[attribute] = xproc.call(value)
            else
              update_attributes(attribute => xproc.call(value))
            end
          end
        end
      end

      list.freeze

      validate = options.fetch(:validate) { { presence: true }.freeze }
      validation = {}

      if validate
        if validate[:presence] == false
          validation[:inclusion] = { in: [ nil, "" ] + list }
        else
          validation[:inclusion] = { in: list }
          validation[:presence] = { allow_blank: false }
        end

        validation[:inclusion].
          merge!(message: "'%{value}' is not a valid #{attribute}")

        validates attribute, validation
      end
    end

    private

    def option_(value, default)
      case value
      when false
        false
      when true
        option_(default, nil)
      when nil
        "".freeze
      else
        "#{value}_"
      end
    end
  end
end
