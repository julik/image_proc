require 'rake'
require 'rake/testtask'

desc "Run tests (you got to have either SIPS or Imagick "
Rake::TestTask.new("test") { |t|
  t.libs << "test"
  t.pattern = '*_test.rb'
  t.verbose = true
}
task :default => [ :test ]

begin
  require 'rubygems'
  require 'rcov/rcovtask'
  desc "just rcov minus html output"
  Rcov::RcovTask.new do |t|
    t.test_files = FileList['*_test.rb']
    t.verbose = true
  end
  
  desc 'Aggregate code coverage for unit, functional and integration tests'
  Rcov::RcovTask.new("coverage") do |t|
    t.test_files = FileList["*_test.rb"]
    t.output_dir = "coverage"
    t.verbose = true
    t.rcov_opts << '--aggregate coverage.data'
  end
rescue LoadError
  puts 'Rcov is not available. Proceeding without...'
end
