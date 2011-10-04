{
  :en => {
    :messages => {
      :new_match => lambda {|key, options|
        match = options[:match]
        personal_pronoun = match.female? ? "her" : "him"
        "Hi #{options[:name]}, #{match.username} wants 2 chat with u! Send #{personal_pronoun} a msg now by replying to this txt. e.g. 'Hi #{match.name} how r u?' Reply with 'bye' 2 stop chatting"
      }
    }
  }
}

