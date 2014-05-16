web: bundle exec unicorn -p $PORT -c ./unicorn.rb
worker: env TERM_CHILD=1 QUEUES=* bundle exec rake jobs:work
