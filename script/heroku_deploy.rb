#!/usr/bin/env ruby

raise "Edit #{__FILE__} to remove any old rake tasks from running then run with --confirm" unless ARGV[1] == "--confirm"

if ARGV[0] == "chibi"
  heroku_app = "--app chibi"
  git_remote = "heroku master"
else
  heroku_app = "--app chibi-staging"
  git_remote = "staging staging:master"
end

puts `heroku maintenance:on #{heroku_app}`
puts `heroku scale non_essential_task_worker=0 #{heroku_app}`
puts `heroku scale urgent_task_worker=0 #{heroku_app}`
puts `git push #{git_remote}`
puts `heroku scale non_essential_task_worker=0 #{heroku_app}`
puts `heroku scale urgent_task_worker=0 #{heroku_app}`
puts `heroku run rake db:migrate #{heroku_app}`

# Enter any custom Rake tasks here: e.g.
#`heroku run rake users:set_operator_name #{heroku_app}`

puts `heroku maintenance:off #{heroku_app}`
puts `heroku scale urgent_task_worker=1 #{heroku_app}` if ARGV[0] == "chibi"
