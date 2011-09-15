# Change this to use commands from different languages
command_languages = ["en", "kh"]

all_commands = YAML.load_file(File.dirname(__FILE__) << '/../message_commands.yml')
message_commands = {}
all_commands.each do |name, command_language|
  message_commands[name] = []
  command_languages.each do |language|
    # union the commands
    message_commands[name] |= command_language[language] if command_language[language]
  end
end

MessageHandler.commands = message_commands.symbolize_keys

