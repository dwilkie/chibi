web: bundle exec thin start -p $PORT
worker: bundle exec rake resque:work QUEUE=message_processor_queue,dialer_queue
highloadworker: bundle exec rake resque:work QUEUE=chat_reactivator_queue,chat_deactivator_queue,chat_expirer_queue,friend_messenger_queue,friend_finder_queue,user_reminderer_queue,reminderer_queue
