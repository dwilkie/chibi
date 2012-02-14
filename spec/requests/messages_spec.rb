require 'spec_helper'

describe "Messages" do
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

    context "given I am currently in a chat session" do
      before do
        # ensure that joy is the first match by increasing her initiated chat count
        create(:chat, :user => joy)
        initiate_chat(dave)
      end

      context "and I text" do
        context "'new'" do
          before do
            send_message(:from => dave.mobile_number, :body => "new")
          end

          it "should end my current chat and start a new one" do
            reply_to(dave).body.should == spec_translate(
              :personalized_new_chat_started,
              dave.locale, dave.name.capitalize, mara.screen_id,
            )
          end
        end

        context "'stop'" do
          before do
            send_message(:from => dave.mobile_number, :body => "stop")
          end

          it "should end my current chat and log me out" do
            reply_to(dave).body.should == spec_translate(
              :logged_out, dave.locale
            )
          end
        end

        context "'Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234'" do
          before do
            send_message(:from => dave.mobile_number, :body => "Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234")
            dave.reload
          end

          it "should forward my message to my chat partner" do
            dave.name.should_not == "sok"
            dave.age.should_not == 27
            dave.location.city.should_not == "Kampong Thom"
            dave.mobile_number.should_not == "012232234"
            reply_to(joy).body.should == "dave#{dave.id}: Hi knyom sok 27 nov kt want 2 chat with me? 012 232 234"
          end
        end
      end

      context "and my partner texts" do

        shared_examples_for "ending my current chat" do
          it "should end my current chat and give me instructions on how to start a new one" do
            reply_to(dave).body.should == spec_translate(
              :chat_has_ended, dave.locale
            )
          end
        end

        context "'new'" do
          before do
            send_message(:from => joy.mobile_number, :body => "new")
          end

          it_should_behave_like "ending my current chat"
        end

        context "'stop'" do
          before do
            send_message(:from => joy.mobile_number, :body => "stop")
          end

          it_should_behave_like "ending my current chat"
        end

        context "'Hi Dave, knyom sara bong nov na?'" do
          before do
            send_message(:from => joy.mobile_number, :body => "Hi Dave, knyom sara bong nov na?")
            joy.reload
          end

          it "should forward her message to me" do
            joy.name.should_not == "sara"
            reply_to(dave).body.should == spec_translate(
              :forward_message, dave.locale, joy.screen_id, "Hi Dave, knyom sara bong nov na?"
            )
          end
        end
      end
    end
  end
end
