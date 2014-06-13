# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'rspec', :keep_failed => false, :cmd => "rspec -t focus" do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }

  # Rails example
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }
  # Capybara request specs
  watch(%r{^app/views/(.+)/(.+)\.(erb|haml)$})          { |m| ["spec/requests/#{m[1]}_spec.rb", "spec/views/#{m[1]}/#{m[2]}.#{m[3]}_spec.rb"] }
end
