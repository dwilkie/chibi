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
    country_code "XY"

    factory :cambodia do
      country_code "KH"

      factory :phnom_penh do
        city "Phnom Penh"
        latitude 11.558831
        longitude 104.917445
      end
    end

    factory :thailand do
      country_code "TH"

      factory :chiang_mai do
        city "Samoeng"
        latitude 18.7964642
        longitude 98.6600586
      end
    end

    factory :vietnam do
      country_code "VN"
    end
  end

  factory :user do
    sequence(:mobile_number, 85597000000) {|n| n.to_s }
    location

    factory :user_with_complete_profile do
      name "veronica"
      date_of_birth { 23.years.ago }
      gender "f"
      looking_for "m"
    end

    # users with unknown details
    factory :alex do
      name "alex"
    end

    factory :jamie do
      name "jamie"
    end

    # user with unknown gender
    factory :chamroune do
      name "chamroune"
      looking_for "f"
    end

    # user with unknown looking for preference
    factory :pauline do
      name "pauline"
      gender "f"
    end

    # straight girl
    factory :nok do
      name "nok"
      gender "f"
      looking_for "m"
      association :location, :factory => :chiang_mai
    end

    # straight guy
    factory :dave do
      name "dave"
      gender "m"
      looking_for "f"
      association :location, :factory => :phnom_penh
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
      association :location, :factory => :vietnam

      factory :view do
        name "view"
        association :location, :factory => :chiang_mai
      end
    end

    # bi girl
    factory :mara do
      name "mara"
      gender "f"
      looking_for "e"
      association :location, :factory => :phnom_penh
    end

    # bi guy
    factory :michael do
      name "michael"
      gender "m"
      looking_for "e"
      association :location, :factory => :chiang_mai
    end
  end
end
