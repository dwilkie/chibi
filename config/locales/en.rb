{
  :en => {
    :messages => {
      :new_match => lambda {|key, options|
        name = options[:name]
        match = options[:match]
        personal_pronoun = match ? (match.female? ? "her" : "him") : "them"
        reply = "Hi"
        reply << name if name
        reply << ", #{match.username} wants 2 chat. Send #{personal_pronoun} a msg now or reply with 'bye bye' 2 stop and meet someone new"
      }
    }
  }
}

