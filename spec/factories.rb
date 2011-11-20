FactoryGirl.define do
  factory :chat do
    association :user, :factory => :registered_user
    association :friend, :factory => :registered_user
  end

  factory :active_chat, :parent => :chat do
    after_create do |chat|
      chat.active_users << chat.user
      chat.active_users << chat.friend
      chat.save
    end
  end

  factory :location do
    country_code "KH"
  end

  factory :user do
    sequence(:mobile_number, 85597000000) {|n| n.to_s }

    factory :user_with_empty_profile do
    end

    # straight girl
    factory :nok do
      gender "f"
      looking_for "m"
    end

    # straight guy
    factory :dave do
      name "dave"
      gender "m"
      looking_for "f"
    end

    # lesbians
    factory :harriet do
      name "harriet"
      gender "f"
      looking_for "f"

      factory :eva do
        name "eva"
      end
    end

    # gays
    factory :hanh do
      name "hanh"
      gender "m"
      looking_for "m"

      factory :view do
        name "view"
      end
    end

    # bi girl
    factory :mara do
      name "mara"
      gender "f"
      looking_for "e"
    end

    # bi guy
    factory :michael do
      name "michael"
      gender "m"
      looking_for "e"
    end
  end
end

