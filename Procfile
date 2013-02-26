web: bundle exec thin start -p $PORT
urgent_task_worker: bundle exec rake resque:work QUEUE=message_processor_queue,dialer_queue
non_essential_task_worker: bundle exec rake resque:work QUEUE=chat_reactivator_queue,chat_deactivator_queue,chat_expirer_queue,friend_messenger_queue,friend_finder_queue,user_reminderer_queue,reminderer_queue
long_running_task_worker: bundle exec rake resque:work QUEUE=reply_state_setter_queue
