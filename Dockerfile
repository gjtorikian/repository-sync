FROM ruby:2.2.4
MAINTAINER @ojacques

RUN gem install bundler rake

ENV app /app
RUN git clone https://github.com/gjtorikian/repository-sync.git $app
WORKDIR $app
ADD . $app

RUN bundle install
