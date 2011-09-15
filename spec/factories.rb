FactoryGirl.define do
  factory :user do
    sequence(:mobile_number, 85597000000) {|n| n.to_s }

    factory :user_with_registered_details do
      location "Phnom Penh"
      state "registered_details"

      trait :male do
        dob { 24.years.ago }
        name "Sok"
        sequence(:username) {|n| "sok#{n}" }
        sex "m"
      end

      trait :female do
        dob { 21.years.ago }
        name "Srey mau"
        sequence(:username) {|n| "sreymau#{n}" }
        sex "f"
      end

      male

      factory :user_with_registered_interests do
        state "registered_interests"

        factory :user_with_registered_looking_for do
          looking_for "f"
          state "registered_looking_for"

          factory :registered_user do
            state "ready"

            factory :female_registered_user do
              female

              factory :straight_female_registered_user do
                looking_for "m"
              end
            end
          end
        end
      end
    end
  end
end

