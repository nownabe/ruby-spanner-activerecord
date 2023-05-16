# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
        def execute_ddl statements
          log "MIGRATION", "SCHEMA" do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              puts "==== #{self.class}#execute_ddl ===="
              p statements
              puts
              @connection.execute_ddl statements
            end
          end
        rescue Google::Cloud::Error => error
          raise ActiveRecord::StatementInvalid, error
        end
      end
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

          puts "==== #{self.class}#create_table ===="
          p statements
          puts

          execute_schema_statements statements
        end
      end
    end
  end
end

module ActiveRecordSpannerAdapter
  class Connection
    def execute_ddl statements, operation_id: nil, wait_until_done: true
      raise "DDL cannot be executed during a transaction" if current_transaction&.active?
      self.current_transaction = nil

      statements = Array statements
      return unless statements.any?

      # If a DDL batch is active we only buffer the statements on the connection until the batch is run.
      if @ddl_batch
        @ddl_batch.push(*statements)
        return true
      end

      puts "==== #{self.class}#execute_ddl ===="
      p statements
      puts

      execute_ddl_statements statements, operation_id, wait_until_done
    end

    def execute_ddl_statements statements, operation_id, wait_until_done
      puts "==== #{self.class}#execute_ddl_statements ===="
      p statements
      puts
      job = database.update statements: statements, operation_id: operation_id
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.done?
    end
  end
end

module Google
  module Cloud
    module Spanner
      class Database
        def update statements: [], operation_id: nil
          ensure_service!
          puts "==== #{self.class}#update ===="
          p statements
          puts
          grpc = service.update_database_ddl instance_id, database_id,
                                             statements: statements,
                                             operation_id: operation_id
          Database::Job.from_grpc grpc, service
        end
      end

      module Admin
        module Database
          module V1
            module DatabaseAdmin
              class Client
                def update_database_ddl request, options = nil
                  raise ::ArgumentError, "request must be provided" if request.nil?

                  request = ::Gapic::Protobuf.coerce request, to: ::Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest

                  # Converts hash and nil to an options object
                  options = ::Gapic::CallOptions.new(**options.to_h) if options.respond_to? :to_h

                  # Customize the options with defaults
                  metadata = @config.rpcs.update_database_ddl.metadata.to_h

                  # Set x-goog-api-client and x-goog-user-project headers
                  metadata[:"x-goog-api-client"] ||= ::Gapic::Headers.x_goog_api_client \
                    lib_name: @config.lib_name, lib_version: @config.lib_version,
                    gapic_version: ::Google::Cloud::Spanner::Admin::Database::V1::VERSION
                  metadata[:"x-goog-user-project"] = @quota_project_id if @quota_project_id

                  header_params = {}
                  if request.database
                    header_params["database"] = request.database
                  end

                  request_params_header = header_params.map { |k, v| "#{k}=#{v}" }.join("&")
                  metadata[:"x-goog-request-params"] ||= request_params_header

                  options.apply_defaults timeout:      @config.rpcs.update_database_ddl.timeout,
                                         metadata:     metadata,
                                         retry_policy: @config.rpcs.update_database_ddl.retry_policy

                  options.apply_defaults timeout:      @config.timeout,
                                         metadata:     @config.metadata,
                                         retry_policy: @config.retry_policy

                  puts "==== #{self.class}#update_database_ddl ===="
                  p request
                  p options
                  puts
                  @database_admin_stub.call_rpc :update_database_ddl, request, options: options do |response, operation|
                    response = ::Gapic::Operation.new response, @operations_client, options: options
                    yield response, operation if block_given?
                    return response
                  end
                rescue ::GRPC::BadStatus => e
                  raise ::Google::Cloud::Error.from_error(e)
                end
              end
            end
          end
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
      system(%Q[$(go env GOPATH)/bin/spanner-cli -p test-project -i test-instance -d #{database_id} -e "SHOW CREATE TABLE `dynamic_items`"])
      puts

      item = DynamicItem.create!
      item.reload
      assert(item.col_timestamp)
    end
  end
end
