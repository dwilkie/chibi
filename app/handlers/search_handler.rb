class SearchHandler < MessageHandler
  def process!
    extract_user_details

#    reply I18n.t(
#      "messages.new_match",
#      :match => User.match(user),
#      :name => user.name
#    )
  end

  private

  def extract_user_details
    stripped_body = self.body.dup

    profile_complete = user.profile_complete?

    extract_gender_and_looking_for(stripped_body, profile_complete)
    extract_date_of_birth(stripped_body, profile_complete)
    extract_name(stripped_body, profile_complete)
    extract_location(stripped_body, profile_complete)
  end

  def extract_gender_and_looking_for(body, force_update)
    unless includes_gender_and_looking_for?(body)
      extract_looking_for(body, :include_shared_gender_words => user.gender.present?)
      extract_gender(body, force_update)
    end
  end

  def extract_date_of_birth(body, force_update)
    match = strip_match!(body, /(\d{2})\s*#{keywords(:years_old)}?/i).try(:[], 1)
    user.age = match.to_i if match && (force_update || user.date_of_birth.nil?)
  end

  def extract_name(body, force_update)
    match = strip_match!(body, /\A#{keywords(:i_am)}\s*(\b\w+\b)/i).try(:[], 2)
    user.name = match.downcase if match && (force_update || user.name.nil?)
  end

  def extract_location(body, force_update)
    if force_update || !location.city?
      location.address = body
      location.locate!
    end
  end

  def includes_gender_and_looking_for?(body)
    tmp_body = body.dup
    if sex = gender(tmp_body, :only_first => true)
      if wants = looking_for(tmp_body, :use_only_shared_gender_words => true)
        # we have the sex and looking for already so remove all references to
        # gender and looking for from the message
        gender(body, :only_first => true)
        looking_for(body, :include_shared_gender_words => true)
        user.gender = sex
        user.looking_for = wants
        body = tmp_body
      end
    end
  end

  def extract_looking_for(body, options = {})
    user_looking_for = looking_for(body, options)
    user.looking_for = user_looking_for if user_looking_for
  end

  def extract_gender(body, force_update)
    sex = gender(body)
    user.gender = sex if sex && (user.gender.nil? || force_update)
  end

  def looking_for(body, options = {})
    if looking_for_girl?(body, options)
      "f"
    elsif looking_for_boy?(body, options)
      "m"
    elsif !options[:use_only_shared_gender_words] && looking_for_friend?(body)
      "e"
    end
  end

  def gender(body, options = {})
    text = options[:only_first] ? includes_gender?(body, options).try(:[], 0).to_s : body
    if from_girl?(text, options)
      "f"
    elsif from_boy?(text, options)
      "m"
    end
  end

  def looking_for?(sex, body, options)
    looking_for = "#{sex}friend"
    could_mean = "could_mean_#{sex}_or_#{looking_for}"

    if options[:include_shared_gender_words]
      regexp = /\b#{keywords(could_mean, looking_for)}\b/i
    elsif options[:use_only_shared_gender_words]
      regexp = /\b#{keywords(could_mean)}\b/i
    else
      regexp = /\b#{keywords(looking_for)}\b/i
    end
    strip_match!(body, regexp)
  end

  def looking_for_girl?(body, options = {})
    looking_for?(:girl, body, options)
  end

  def looking_for_boy?(body, options = {})
    looking_for?(:boy, body, options)
  end

  def looking_for_friend?(body)
    strip_match!(body, /\b#{keywords(:friend)}\b/i)
  end

  def includes_gender?(body, options)
    strip_match!(
      body,
      /#{keywords(:i_am)}?\s*\b#{keywords(:could_mean_boy_or_boyfriend, :boy, :could_mean_girl_or_girlfriend, :girl)}\b/i,
      options
    )
  end

  def from?(sex, body, options)
    could_mean = "could_mean_#{sex}_or_#{sex}friend"
    strip_match!(body, /#{keywords(:i_am)}?\s*\b#{keywords(sex, could_mean)}\b/i, options)
  end

  def from_girl?(body, options = {})
    from?(:girl, body, options)
  end

  def from_boy?(body, options = {})
    from?(:boy, body, options)
  end

  def strip_match!(body, regexp, options = {})
    options[:only_first] ? body.sub!(regexp, "") : body.gsub!(regexp, "")
    body.strip!
    $~
  end
end

