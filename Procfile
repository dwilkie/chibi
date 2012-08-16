web: bundle exec thin start -p $PORT
worker: bundle exec rake resque:work QUEUE=message_processor_queue,dialer_queue,chat_deactivator_queue,friend_messenger_queue,chat_expirer_queue,friend_finder_queue,chat_reactivator_queue,user_reminder_queue
