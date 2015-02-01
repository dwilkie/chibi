web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker: bundle exec sidekiq -q critical,64 -q urgent,32 -q very_high,16 -q high,8 -q default,4 -q low,2 -q very_low,1
