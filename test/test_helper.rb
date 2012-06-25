require 'test/unit'
require 'rubygems'
require 'active_record'
require File.dirname(__FILE__) + '/../lib/rails_csv_importer.rb'

def load_schema
  config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))

  db_adapter = ENV['DB']

  # if no db specified, try sqlite3 by default.
  db_adapter ||=
    begin
      require 'sqlite3'
      'sqlite3'
    rescue MissingSourceFile
    end

  if db_adapter.nil?
    raise "No DB Adapter selected. Pass the DB= option to pick one, or install Sqlite3."
  end

  ActiveRecord::Base.establish_connection(config[db_adapter])
  load(File.dirname(__FILE__) + "/schema.rb")
end

class Test::Unit::TestCase
  @@fixtures = {}
  def self.fixtures list
    [list].flatten.each do |fixture|
      self.class_eval do
        define_method(fixture) do |item|
          @@fixtures[fixture] ||= YAML::load_file("test/fixtures/#{fixture.to_s}.yaml")
          @@fixtures[fixture][item.to_s]
        end
      end
    end
  end
end

