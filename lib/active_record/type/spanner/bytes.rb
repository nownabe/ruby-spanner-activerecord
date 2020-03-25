# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class Bytes < ActiveRecord::Type::Binary
        def serialize value
          if value.respond_to?(:read) && value.respond_to?(:rewind)
            value.rewind
            value = value.read
          end

          value = Base64.strict_encode64(
            value.force_encoding("ASCII-8BIT")
          )
          super value
        end

        def deserialize value
          return if value.nil?
          return value.to_s if value.is_a? Type::Binary::Data
          return Base64.decode64 value.read if value.is_a? StringIO

          value
        end
      end
    end
  end
end