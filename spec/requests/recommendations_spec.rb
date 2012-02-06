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
    context "given there are no matches for me" do
      context "when I text 'hello'" do
        before do
          send_message(:from => my_number, :body => "hello")
        end

        it "should reply saying there are no matches at this time" do
          replies.count.should == 1

          last_reply.body.should == spec_translate(
            :could_not_start_new_chat,
            :users_name => nil,
            :locale => new_user.locale
          )

          last_reply.to.should == my_number
        end
      end
    end
  end

  context "as an existing user" do
    before do
      load_users
    end

    context "with missing profile information" do

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

            reply_to_user.body.should == spec_translate(
              :new_chat_started,
              :users_name => alex.name,
              :friends_screen_name => dave.screen_id,
              :to_user => true,
              :locale => new_user.locale
            )

            reply_to_user.to.should == alex.mobile_number

            reply_to_friend.body.should == spec_translate(
              :new_chat_started,
              :users_name => dave.name,
              :friends_screen_name => alex.screen_id,
              :to_user => false,
              :locale => new_user.locale
            )

            reply_to_friend.to.should == dave.mobile_number
          end
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

        it "should start a chat between the new user and an existing user and notify both users" do
          assert_new_user

          reply_to_user.body.should == spec_translate(
            :new_chat_started,
            :users_name => nil,
            :friends_screen_name => alex.screen_id,
            :to_user => true,
            :locale => new_user.locale
          )
          reply_to_user.to.should == my_number

          reply_to_friend.body.should == spec_translate(
            :new_chat_started,
            :users_name => alex.name,
            :friends_screen_name => new_user.screen_id,
            :to_user => false,
            :locale => new_user.locale
          )

          reply_to_friend.to.should == alex.mobile_number
        end
      end

      context "'knyom map pros 27 pp jong rok met srey'" do
        before do
          # ensure that joy is the first match by increasing her initiated chat count
          create(:chat, :user => joy)
          send_message(:from => my_number, :body => "knyom map pros 27 pp jong rok met srey", :location => true)
        end

        it "should create a new user called 'map' and start a chat with a girl close to phnom penh" do
          assert_new_user

          new_user.name.should == "map"
          new_user.age.should == 27
          new_user.location.city.should == "Phnom Penh"
          new_user.looking_for.should == "f"
          new_user.gender.should == "m"

          reply_to_user.body.should == spec_translate(
            :new_chat_started,
            :users_name => "Map",
            :friends_screen_name => joy.screen_id,
            :to_user => true,
            :locale => new_user.locale
          )

          reply_to_user.to.should == my_number

          reply_to_friend.body.should == spec_translate(
            :new_chat_started,
            :users_name => joy.name,
            :friends_screen_name => new_user.screen_id,
            :to_user => false,
            :locale => joy.locale
          )

          reply_to_friend.to.should == joy.mobile_number
        end
      end
    end
  end
end
