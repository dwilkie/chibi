class SearchHandler < MessageHandler

  def process!
    extract_missing_details

    reply I18n.t(
      "messages.new_match",
      :match => User.match(user),
      :name => user.name
    )
  end

  private

  def extract_missing_details
    if user.missing_details?
      # kjom sok 23chnam phnom penh jong rok mit srey
      body =~ /kjom sok 23chnam phnom penh jong rok mit srey/
    end
  end

end

