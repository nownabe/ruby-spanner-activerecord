# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module Models
  class DefaultValueTest < SpannerAdapter::TestCase
    include TestHelpers::WithSeparateDatabase

    class DynamicItem < ActiveRecord::Base; end

    def test_dynamic_default_values
      connection.create_table :dynamic_items do |t|
        t.column :col_timestamp, :datetime, default: -> { "CURRENT_TIMESTAMP()" }
      end

      puts "==== spanner-cli ===="
      system(%Q[$GOPATH/bin/spanner-cli -p test-project -i test-instance -d #{database_id} -e "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='dynamic_items' ORDER BY ORDINAL_POSITION ASC;"])
      puts "==== spanner-cli ===="

      item = DynamicItem.create!
      item.reload
      assert(item.col_timestamp)
    end
  end
end
