# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module Models
  class DefaultValueTest < SpannerAdapter::TestCase
    include TestHelpers::WithSeparateDatabase

    class StaticItem < ActiveRecord::Base; end
    class DynamicItem < ActiveRecord::Base; end

    def test_static_default_values
      # skip "default values don't work for now"
      connection.create_table :static_items do |t|
        t.column :col_string, :string, default: "default"
        t.column :col_int64, :bigint, default: 123
        t.column :col_float64, :float, default: 1.23
        t.column :col_numeric, :numeric, default: BigDecimal("1.23")
        t.column :col_bool, :boolean, default: true
        # t.column :col_bytes, :binary, default: 'B"binary"'
        t.column :col_date, :date, default: Date.new(2023, 5, 9)
        t.column :col_timestamp, :datetime, default: DateTime.new(2023, 5, 9, 1, 2, 3)
        # t.column :col_json, :json, default: {a: "b"}

        # t.column :col_array_string, :string, array: true, default: ["def", "ault"]
        # t.column :col_array_int64, :bigint, array: true, default: [123, 456]
        # t.column :col_array_float64, :float, array: true, default: [1.23, 4.56]
        # t.column :col_array_numeric, :numeric, array: true, default: [BigDecimal("1.23"), BigDecimal("4.56")]
        # t.column :col_array_bool, :boolean, array: true, default: [true, false]
        # t.column :col_array_bytes, :binary, array: true, default: [0b1010, 0b0101]
        # t.column :col_array_date, :date, array: true, default: [Date.new(2023, 5, 9), Date.new(2023, 5, 10)]
        # t.column :col_array_timestamp, :datetime, array: true, default: [DateTime.new(2023, 5, 9, 1, 2, 3), DateTime.new(2023, 5, 10, 4, 5, 6)]
        # t.column :col_array_json, :json, array: true, default: [{a: "b"}.to_json, {c: "d"}.to_json]
      end

      item = StaticItem.create!
      binding.irb
      item.reload
      binding.irb
      # assert_equal("default", item.col_string)
      assert_equal(123, item.col_int64)
      assert_equal(1.23, item.col_float64)
      assert_equal(BigDecimal("1.23"), item.col_numeric)
      assert_equal(true, item.col_bool)
      # assert_equal(0b1010, item.col_bytes)
      assert_equal(Date.new(2023, 5, 9), item.col_date)
      assert_equal(DateTime.new(2023, 5, 9, 1, 2, 3), item.col_timestamp)
      # assert_equal({a: "b"}.to_json, item.col_json)
      # assert_equal(["def", "ault"], item.col_array_string)
      # assert_equal([123, 456], item.col_array_int64)
      # assert_equal([1.23, 4.56], item.col_array_float64)
      # assert_equal([BigDecimal("1.23"), BigDecimal("4.56")], item.col_array_numeric)
      # assert_equal([true, false], item.col_array_bool)
      # assert_equal([0b1010, 0b0101], item.col_array_bytes)
      # assert_equal([Date.new(2023, 5, 9), Date.new(2023, 5, 10)], item.col_array_date)
      # assert_equal([DateTime.new(2023, 5, 9, 1, 2, 3), DateTime.new(2023, 5, 10, 4, 5, 6)], item.col_array_timestamp)
      # assert_equal([{a: "b"}.to_json, {c: "d"}.to_json], item.col_array_json)
    end

    def test_dynamic_default_values
      connection.create_table :dynamic_items do |t|
        t.column :col_timestamp, :datetime, default: -> { "CURRENT_TIMESTAMP()" }
      end

      item = DynamicItem.create!
      item.reload
      assert(item.col_timestamp)
    end
  end
end
