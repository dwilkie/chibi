FactoryGirl.define do

  factory :account do
    sequence(:username) {|n| "testaccount#{n}" }
    sequence(:email) {|n| "testaccount#{n}@example.com" }
    password "foobar"
  end

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

  factory :user do
    sequence(:mobile_number, 85597000000) {|n| n.to_s }

    factory :user_with_registered_details do
      location "Phnom Penh"
      state "registered_details"

      trait :male do
        date_of_birth { 24.years.ago }
        name "Sok"
        sequence(:username) {|n| "sok#{n}" }
        gender "m"
      end

      trait :female do
        date_of_birth { 21.years.ago }
        name "Srey mau"
        sequence(:username) {|n| "sreymau#{n}" }
        gender "f"
      end

      male

      factory :user_with_registered_interests do
        # add interests here
        state "registered_interests"

        factory :registered_user do
          state "ready"

          factory :registered_female_user do
            female

            factory :girl_looking_for_guy do
              looking_for "m"

              factory :chatting_girl_looking_for_guy do
                after_create { |user| FactoryGirl.create(:active_chat, :friend => user) }
              end
            end

            factory :girl_looking_for_girl do
              looking_for "f"
            end
          end

          factory :registered_male_user do
            male

            factory :guy_looking_for_girl do
              looking_for "f"
            end

            factory :guy_looking_for_guy do
              looking_for "m"
            end
          end
        end
      end
    end
  end
end

