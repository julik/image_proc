require 'rake'
require 'rake/testtask'

desc "Run tests (you got to have either SIPS or Imagick "
Rake::TestTask.new("test") { |t|
  t.libs << "test"
  t.pattern = '*_test.rb'
  t.verbose = true
}
task :default => [ :test ]
