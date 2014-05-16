web: bundle exec rackup config.ru -p $PORT
worker: bundle exec rake jobs:work TERM_CHILD=1 QUEUES=*
