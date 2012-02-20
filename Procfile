web: bundle exec thin start -p $PORT
worker: QUEUES=message_processor_queue,chat_deactivator_queue,chat_expirer_queue bundle exec rake environment resque:work
