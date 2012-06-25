require 'test_helper'

class Category < ActiveRecord::Base
end

class Material < ActiveRecord::Base
  validates_presence_of :name
  belongs_to :category

  acts_as_rails_csv_importer
end

class ActsAsCsvImporterTest < Test::Unit::TestCase
  def self.startup
    load_schema

    # load fixtures
    Category.create!(:name => 'Category1')
    Category.create!(:name => 'Category2')
  end

  def setup
    Material.delete_all
  end

  test "basic functionalities" do
    import_material_config = {
      :mapping => {
        'name' => {},
        'fragile' => {:name => "Fragile?", :value_method => Acts::RailsCsvImporter::ValueMethods.yes_no_value_method},
        'category_id' =>  {:record_method => lambda { |v, row, mapping| Category.find_by_name(v) } },
      },
    }

    assert_equal ["Category","Fragile?","Name"], Material.get_csv_import_template(import_material_config).strip.split(',').sort

    assert_equal 1, Material.import_from_csv(import_material_config, "name,fragile?,category\nMaterial1,yes,Category1")
    assert_equal 1, Material.all.length
    assert_equal "Material1", Material.first.name
    assert Material.first.fragile
    assert_equal "Category1", Material.first.category.name
  end

  test "create new or update existing record" do
    import_material_config = {
      :mapping => {
        'name' => {},
        'fragile' => {},
        'category_id' =>  {:record_method => lambda { |v, row, mapping| Category.find_by_name(v) } },
      },
      :find_existing => lambda { |row| Material.find_by_name(row['name']) }
    }

    Material.create!(:name => 'Material1', :fragile => false)

    assert_equal 2, Material.import_from_csv(import_material_config, "Name,Fragile,Category\nMaterial1,T,Category1\nMaterial2,false,Category2")
    assert_equal 2, Material.all.length
    m1 = Material.find_by_name('Material1')
    m2 = Material.find_by_name('Material2')
    assert m1.fragile
    assert_equal "Category1", m1.category.name
    assert_equal false, m2.fragile
    assert_equal "Category2", m2.category.name
  end

  test "model validation error handling" do
    import_material_config = {
      :mapping => {
        'name' => {},
        'fragile' => {},
      },
    }

    ex = nil

    begin
      Material.import_from_csv(import_material_config, "Name,Fragile\nMaterial1,false\n,true")
    rescue Acts::RailsCsvImporter::RailsCsvImportError => e
      ex = e
    end

    assert_equal "Fragile,Name", ex.header_row.sort.join(',')
    assert_equal 1, ex.num_imported
    assert_equal 1, ex.errors.length
    assert_equal ["Name can't be blank"], ex.errors.first.first.full_messages
    assert_equal ",true", ex.errors.first.last.sort.join(',')
  end


  test "exception in value/record method" do
    import_material_config = {
      :mapping => {
        'name' => {},
        'fragile' => {:value_method => lambda { |v, row, mapping| raise 'tada!' } },
      },
    }

    ex = nil

    begin
      Material.import_from_csv(import_material_config, "Name,Fragile\nMaterial1,false")
    rescue Acts::RailsCsvImporter::RailsCsvImportError => e
      ex = e
    end

    assert_equal "Failed to import column 'Fragile': tada!", ex.errors.first.first
  end

  test "Mailformed CSV handling" do
    import_material_config = {
      :mapping => {
        'name' => {},
        'fragile' => {},
      },
    }

    ex = nil

    begin
      Material.import_from_csv(import_material_config, "Name,\"Fragile\nMaterial1,false")
    rescue Acts::RailsCsvImporter::RailsCsvImportError => e
      ex = e
    end

    assert_match "Invalid CSV format: ", ex.errors.first.first
  end

  test "Invalid UTF8 coding handling" do
    import_material_config = {
      :mapping => {
        'name' => {},
        'fragile' => {},
      },
    }

    ex = nil

    begin
      Material.import_from_csv(import_material_config, "Name,Fragile\nMaterial1\x94,false")
    rescue Acts::RailsCsvImporter::RailsCsvImportError => e
      ex = e
    end

    assert_match "Invalid character encountered in row ", ex.errors.first.first
  end
end

