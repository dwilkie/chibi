{
  :en => {
    :messages => {
      :new_match => lambda {|key, options|
        name = options[:name]
        match = options[:match]
        personal_pronoun = match ? (match.female? ? "her" : "him") : "them"
        reply = "Hi"
        reply << name if name
        reply << ", we found a match 4 u! #{match.username} wants 2 chat. Send #{personal_pronoun} a msg now by replying to this txt. e.g. 'Hi how r u?' Reply with 'bye bye' 2 stop chatting"
      }
    }
  }
}

