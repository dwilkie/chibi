Dir[File.join(Rails.root, "lib", "core_ext", "*.rb")].each {|ext| require ext }
