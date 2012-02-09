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
            replies.count.should == 1

            reply_to(new_user).body.should == spec_translate(
              :could_not_start_new_chat,
              :users_name => nil,
              :locale => new_user.locale
            )
          end
        end
      end

      context "'stop'" do
        before do
          send_message(:from => my_number, :body => "stop")
        end

        it "should log me out and tell me how to log in again" do
          replies[0].body.should == spec_translate(
            :logged_out_or_chat_has_ended,
            :missing_profile_attributes => new_user.missing_profile_attributes,
            :logged_out => true,
            :locale => new_user.locale
          )

          replies[0].to.should == my_number
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
            :new_chat_started,
            :users_name => alex.name,
            :friends_screen_name => dave.screen_id,
            :locale => new_user.locale
          )

          reply_to(dave).body.should == spec_translate(
            :new_chat_started,
            :users_name => dave.name,
            :friends_screen_name => alex.screen_id,
            :locale => new_user.locale
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
            :new_chat_started,
            :users_name => nil,
            :friends_screen_name => alex.screen_id,
            :locale => new_user.locale
          )

          reply_to(alex).body.should == spec_translate(
            :new_chat_started,
            :users_name => alex.name,
            :friends_screen_name => new_user.screen_id,
            :locale => new_user.locale
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
            :new_chat_started,
            :users_name => "Map",
            :friends_screen_name => joy.screen_id,
            :locale => new_user.locale
          )

          reply_to(joy).body.should == spec_translate(
            :new_chat_started,
            :users_name => joy.name,
            :friends_screen_name => new_user.screen_id,
            :locale => joy.locale
          )
        end
      end
    end
  end
end
