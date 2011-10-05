{
  :kh => {
    :messages => {
      :new_match => lambda {|key, options|
        name = options[:name]
        match = options[:match]
        personal_pronoun = match ? (match.female? ? "her" : "him") : "them"
        reply = "Sousdey"
        reply << name if name
        reply << ", #{match.username} jong chat jea moy chleuy torb tov neang re ban-chhop chat doy sor-say 'bye bye' rok mit tmey teat"
      }
    }
  }
}

