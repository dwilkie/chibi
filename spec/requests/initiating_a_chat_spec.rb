require 'spec_helper'

describe "Initiating a chat" do
  include MessagingHelpers
  include TranslationHelpers

  include_context "existing users"
  include_context "replies"

  let(:new_user) do
    User.last
  end

  let(:new_location) do
    Location.last
  end

  let(:my_number) { "8553243313" }

  context "as a user" do
    context "when I text" do
      context "'hello'" do
        context "given there are no matches for me" do
          before do
            send_message(:from => my_number, :body => "hello")
          end

          it "should reply telling me that there are no matches at this time" do
            reply_to(new_user).body.should == spec_translate(:could_not_start_new_chat, new_user.locale)
          end
        end
      end

      context "'stop'" do
        before do
          send_message(:from => my_number, :body => "stop")
        end

        it "should log me out and tell me how to log in again" do
          reply_to(new_user).body.should == spec_translate(:anonymous_logged_out, new_user.locale)
        end
      end
    end
  end

  context "as an existing user" do
    before do
      load_users
    end

    context "when I text" do
      context "'23 srey jong rok met pros'" do
        before do
          send_message(:from => alex.mobile_number, :body => "23 srey jong rok met pros")
          alex.reload
        end

        it "should update my profile and connect me with a match" do
          alex.name.should == "alex"
          alex.age.should == 23
          alex.gender.should == "f"
          alex.looking_for.should == "m"

          reply_to(alex).body.should == spec_translate(
            :personalized_new_chat_started, alex.locale, alex.name.capitalize, dave.screen_id
          )

          reply_to(dave).body.should == spec_translate(
            :personalized_new_chat_started, dave.locale, dave.name.capitalize, alex.screen_id
          )
        end
      end
    end
  end

  context "as new user" do

    def assert_new_user
      new_user.mobile_number.should == my_number
      new_location.user.should == new_user
      new_location.country_code.should == "KH"
    end

    before do
      load_users
    end

    context "when I text" do

      context "'hello'" do
        before do
          send_message(:from => my_number, :body => "hello")
        end

        it "should start a chat between an existing anonymous user and myself and notify both of us" do
          assert_new_user

          reply_to(new_user).body.should == spec_translate(
            :anonymous_new_chat_started, new_user.locale, alex.screen_id
          )

          reply_to(alex).body.should == spec_translate(
            :personalized_new_chat_started, alex.locale, alex.name.capitalize, new_user.screen_id
          )
        end
      end

      context "'knyom map pros 27 pp jong rok met srey'" do
        before do
          # ensure that joy is the first match by increasing her initiated chat count
          create(:chat, :user => joy)
          send_message(:from => my_number, :body => "knyom map pros 27 pp jong rok met srey", :location => true)
        end

        it "should save me as 'map' a 27 yo male from Phnom Penh and start a chat with a matching female" do
          assert_new_user

          new_user.name.should == "map"
          new_user.age.should == 27
          new_user.location.city.should == "Phnom Penh"
          new_user.looking_for.should == "f"
          new_user.gender.should == "m"

          reply_to(new_user).body.should == spec_translate(
            :personalized_new_chat_started, new_user.locale, new_user.name.capitalize, joy.screen_id
          )

          reply_to(joy).body.should == spec_translate(
            :personalized_new_chat_started, joy.locale, joy.name.capitalize, new_user.screen_id
          )
        end
      end
    end
  end
end
