FactoryGirl.define do

  factory :account do
    sequence(:username) {|n| "testaccount#{n}" }
    sequence(:email) {|n| "testaccount#{n}@example.com" }
    password "foobar"
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

