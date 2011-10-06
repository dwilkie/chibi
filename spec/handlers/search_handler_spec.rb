require 'spec_helper'

describe SearchHandler do
  let(:user) do
    create(:user)
  end

  let(:user_with_complete_profile) do
    create(:user_with_complete_profile)
  end

  describe "#process!" do

    before do
      Timecop.freeze(Time.now)
    end

    after do
      Timecop.return
    end

    def process_message
      subject.process!
    end

    context "where the message is" do
      #keywords: girlfriend, boyfriend, friend, srey, broh, girl, boy, \bm\b, \bf\b, man, woman, bf, gf, bfriend, gfriend

      # gender unknown
      #   looking_for unknown   (1)
      #   looking_for known     (2)
      # gender known
      #   looking_for unknown   (3)
      #   looking_for known
      #     profile_incomplete (4)
      #     profile_complete   (5)

      # messages:
        # jong rok mit srey
          # 1. {:gender => nil, :looking_for => 'f'}
          # 2. {:gender => nil, :looking_for => 'f'}
          # 3. {:gender => <unchanged>, :looking_for => 'f'}
          # 4. {:gender => <unchanged>, :looking_for => 'f'}
          # 5  {:gender => <unchanged>, :looking_for => 'f'}
        # kjom broh jong rok mit srey
          # 1. {:gender => 'm', :looking_for => 'f'}

      GENDER_EXAMPLES = [
        "jong rok mit srey",
        "kjom broh jong rok mit srey",
        "asdfas asd broh jab srey sweet",
        "kjom girl",
        "boy friend",
        "girl friend",
        "gf",
        "bf"
      ]

      context "'kjom Vichet 23chnam phnom penh jong rok mit srey'", :wip => true do

        def normalize_profile(new_profile_value)
          new_profile_value.is_a?(Proc) ? new_profile_value.call : new_profile_value
        end

        EXPECTED_NEW_PROFILE = {
          :name => "vichet",
          :date_of_birth => Proc.new{ || 23.years.ago.utc },
          :location => "phnom penh",
          :looking_for => "f"
        }

        shared_examples_for "update profile" do
          before do
            subject.user = user_in_context
            process_message
          end

          it "should set/update his profile" do
            user_in_context.send(new_profile_attribute).should == normalize_profile(new_profile_value)
          end
        end

        before do
          subject.body = "kjom Vichet 23chnam phnom penh jong rok mit srey"
        end

        EXPECTED_NEW_PROFILE.each do |attribute, value|
          context "a user" do
            context "with a complete profile" do
              it_should_behave_like "update profile" do
                let(:new_profile_attribute) { attribute }
                let(:new_profile_value) { value }
                let(:user_in_context) { user_with_complete_profile }
              end
            end

            context "with an incomplete profile" do
              context "(his #{attribute} is missing)" do
                it_should_behave_like "update profile" do
                  let(:new_profile_attribute) { attribute }
                  let(:new_profile_value) { value }
                  let(:user_in_context) { user }
                end
              end

              context "(his #{attribute} is already set)" do
                before do
                  subject.user = user
                  user.send("#{attribute}=", user_with_complete_profile.send(attribute))
                  process_message
                end

                it "should not update his #{attribute}" do
                  user.send(attribute).should_not == normalize_profile(value)
                end
              end
            end
          end
        end
      end
    end
  end
end

