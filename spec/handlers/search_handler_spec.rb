require 'spec_helper'

def gender_examples(examples, options)
  gender = options[:gender] || "nil"
  looking_for = options[:looking_for]

  examples.each do |message|
    context "'#{message}'", :focus do
      before do
        subject.user = user
        subject.body = message
        process_message
      end

      context "the user" do
        it "should be #{gender}" do
          user.should send("be_#{gender}")
        end

        context "looking for" do
          if looking_for
            it "should be #{looking_for}" do
              user.looking_for.should == looking_for.to_s[0]
            end
          else
            it "should be unknown" do
              user.looking_for.should be_nil
            end
          end
        end
      end
    end
  end
end

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
      #keywords: girlfriend, boyfriend, friend, srey, bros, broh, girl, boy, \bm\b, \bf\b, man, woman, bf, gf, bfriend, gfriend

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

      LOOKING_FOR_BOY = ["friend boy", "boy friend", "bf", "boyfriend"]
      LOOKING_FOR_FRIEND = ["friend", "mit", "met"]

      GUY_LOOKING_FOR_GIRL = ["kjom broh jong rok mit srey", "asdfas asd m jab girl sweet"]
      GIRL_LOOKING_FOR_GUY = ["kunthia f pp blah broh", "nhom srey jong mian bf"]
      GAY = ["nhom broh jong rok mit bros", "bob m jong mian boy friend"]
      LESBIAN = ["nhom girl jong rok mit srey", "mara f jong mian girl for fun"]
      GUY_LOOKING_FOR_FRIEND = ["nhom boy looking for friend", "dave m jong rok met", "john bros rok mit"]
      GIRL_LOOKING_FOR_FRIEND = ["nhom kunthia f looking for friend", "mara srey jong rok met", "john female rok mit"]

      gender_examples(["bros", "broh", "boy", "m", "male"], :gender => :male, :looking_for => nil)
      gender_examples(["srey", "girl", "f", "female"], :gender => :female, :looking_for => nil)

      gender_examples(["girl friend", "gf", "girlfriend", "jong rok mit srey"], :gender => nil, :looking_for => :female)

      context "'kjom Vichet 23chnam phnom penh jong rok mit srey'" do
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

