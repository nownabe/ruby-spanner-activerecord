# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module SchemaStatements
        def create_table(table_name, id: :primary_key, **options)
          td = create_table_definition table_name, options

          if id
            pk = options.fetch :primary_key do
              Base.get_primary_key table_name.to_s.singularize
            end
            id = id.fetch :type, :primary_key if id.is_a? Hash

            if pk.is_a? Array
              td.primary_keys pk
            else
              td.primary_key pk, id, **{}
            end
          end

          yield td if block_given?

          statements = []

          if options[:force]
            statements.concat drop_table_with_indexes_sql(table_name, options)
          end

          statements << schema_creation.accept(td)

          td.indexes.each do |column_name, index_options|
            id = create_index_definition table_name, column_name, **index_options
            statements << schema_creation.accept(id)
          end

          p statements

          execute_schema_statements statements
        end
      end
    end
  end
end

module Models
  class DefaultValueTest < SpannerAdapter::TestCase
    include TestHelpers::WithSeparateDatabase

    class DynamicItem < ActiveRecord::Base; end

    def test_dynamic_default_values
      connection.create_table :dynamic_items do |t|
        t.column :col_timestamp, :datetime, default: -> { "CURRENT_TIMESTAMP()" }
      end

      puts "==== spanner-cli ===="
      system(%Q[$(go env GOPATH)/bin/spanner-cli -p test-project -i test-instance -d #{database_id} -e "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='dynamic_items' ORDER BY ORDINAL_POSITION ASC;"])
      puts "==== spanner-cli ===="

      item = DynamicItem.create!
      item.reload
      assert(item.col_timestamp)
    end
  end
end
