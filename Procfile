web: bundle exec thin start -p $PORT
worker: bundle exec rake resque:work QUEUE=message_processor_queue,dialer_queue,chat_deactivator_queue,chat_expirer_queue
