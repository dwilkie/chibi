web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
urgent_task_worker_1: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=charge_request_updater_queue bundle exec rake resque:work
urgent_task_worker_2: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=call_data_record_creator_queue bundle exec rake resque:work
urgent_task_worker_3: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=charge_request_updater_queue,message_processor_queue bundle exec rake resque:work
urgent_task_worker_4: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=twilio_cdr_fetcher_queue bundle exec rake resque:work
urgent_task_worker_5: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=delivery_receipt_creator_queue bundle exec rake resque:work
urgent_task_worker_6: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=dialer_queue bundle exec rake resque:work

non_essential_task_worker_1: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=user_creator_queue,user_importer_queue bundle exec rake resque:work
non_essential_task_worker_2: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=chat_deactivator_queue,chat_expirer_queue bundle exec rake resque:work
non_essential_task_worker_3: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=friend_messenger_queue,friend_finder_queue bundle exec rake resque:work
non_essential_task_worker_4: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=user_reminderer_queue,reminderer_queue bundle exec rake resque:work
non_essential_task_worker_5: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=chat_reactivator_queue,chat_reinvigorator_queue bundle exec rake resque:work
non_essential_task_worker_6: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=locator_queue bundle exec rake resque:work
non_essential_task_worker_7: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=9 QUEUE=report_generator_queue bundle exec rake resque:work
