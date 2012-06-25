Gem::Specification.new do |s|
  s.name            = 'rails_csv_importer'
  s.version         = '0.1.1'
  s.date            = '2012-06-20'
  s.summary         = "A little gem to ease data importing in Ruby on Rails"
  s.description     = "Define configuration in a hash and then import Ruby on Rails model data from CSV with one method call."
  s.add_dependency "fastercsv", [">= 1.1.0"]
  s.authors         = ["Ben Li"]
  s.email           = 'libin1231@gmail.com'
  s.files           = Dir['MIT-LICENSE', 'README.rdoc', 'lib/**/*']
  s.require_path    = 'lib'
  s.homepage        = 'http://rubygems.org/gems/rails_csv_importer'
end
