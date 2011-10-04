{
  :kh => {
    :messages => {
      :new_match => lambda {|key, options|
        match = options[:match]
        personal_pronoun = match.female? ? "her" : "him"
        "Hallo #{options[:name]}, #{match.username} chong chat mui bong. Send #{personal_pronoun} a msg now by replying to this txt. e.g. 'Hi #{match.name} how r u?' Reply with 'bye' 2 stop chatting"
      }
    }
  }
}

