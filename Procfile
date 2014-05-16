web: bundle exec rackup config.ru -p $PORT
worker: env TERM_CHILD=1 QUEUES=* bundle exec rake jobs:work
