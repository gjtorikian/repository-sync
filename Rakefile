require './app.rb'
require 'resque/tasks'

task 'resque:setup' do
  ENV['QUEUE'] = '*'
end

require 'rspec/core/rake_task'
desc 'Run specs'
RSpec::Core::RakeTask.new do |t|

end
task :default => [:spec]

desc 'Alias for resque:work (To run workers on Heroku)'
task 'jobs:work' => 'resque:work'

namespace :deploy do
  desc 'Deploy the app'
  task :production do
    app = 'github-repository-sync'
    remote = "git@heroku.com:#{app}.git"

    system "heroku maintenance:on --app #{app}"
    system "git push #{remote} master"
    system "heroku run rake db:migrate --app #{app}"
    system "heroku maintenance:off --app #{app}"
  end
end
