# frozen_string_literal: true

require "google/cloud/spanner"
require "activerecord-spanner-adapter"

project_id = ENV["SPANNER_TEST_PROJECT"]
instance_id = ENV["SPANNER_TEST_INSTANCE"]
database_id = ENV["SPANNER_TEST_DATABASE"]

client = Google::Cloud::Spanner.new(project_id: project_id)

unless client.instance(instance_id)
  client.create_instance(
    instance_id,
    name: "instance",
    config: "emulator-config",
    nodes: 1,
  ).wait_until_done!
end

instance = client.instance(instance_id)
instance.create_database(database_id).wait_until_done!

puts "created instance and database"
