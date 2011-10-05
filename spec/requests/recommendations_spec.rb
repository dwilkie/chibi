require 'spec_helper'

describe "Initiating a chat" do
  include MessagingHelpers
  include TranslationHelpers

  let(:sok) do
    create(:registered_male_user)
  end

  let(:chatting_girl_looking_for_guy) do
    create(:chatting_girl_looking_for_guy)
  end

  let(:boy_looking_for_a_friend) do
    create(:registered_male_user)
  end

  let(:friend_of_sok) do
    create(:chat, :user => sok).friend
  end

  let(:chat_friend_of_sok) do
    create(:chat, :friend => sok).user
  end

  let(:users) do
    [sok, chatting_girl_looking_for_guy, boy_looking_for_a_friend, friend_of_sok, chat_friend_of_sok]
  end

  let(:last_message) do
    Message.last
  end

  let(:reply) do
    Reply.last
  end

  let(:new_user) do
    User.last
  end

  def reload_index_and_commit(reload_instances)
    reload_instances.each do |instance|
      instance.reload.index
    end
    Sunspot.commit
  end

  context "as new user", :wip => true do
    context "when I text", :search => true do
      let(:my_number) { "8553243313" }
      before do
        reload_index_and_commit(users)
      end

      context "'hello'" do
        before do
          send_message(:from => my_number, :body => "hello")
        end

        it "should create a reply for the user which includes a match" do
          reply.body.should == spec_translate(
            :new_match,
            :name => nil,
            :match => sok
          )
          reply.to.should == my_number
        end
      end

      context "'kjom sok 23chnam phnom penh jong rok mit srey'" do
        before do
          send_message(:from => my_number, :body => "kjom sok 23chnam phnom penh jong rok mit srey")
        end

        context "the new user" do
          it "should have name: 'sok'" do
            new_user.name.should == "sok"
          end

          it "should have a date of birth 23 years ago" do
            new_user.date_of_birth.should == 23.years.ago
          end
        end

        it "should create a reply for sok which includes a match who is a girl in phnom penh and younger than 23 years old" do
          reply.body.should == spec_translate(
            :new_match,
            :name => "sok",
            :match => sok
          )
          reply.to.should == my_number
        end

      end
    end
  end

  context "as an existing user" do
    context "and there are other users in the system", :search => true do

      before(:all) do
        reload_index_and_commit(users)
      end

      context "when he searches" do
        before(:all) do
          search(sok)
        end

        it "should find him a match" do
          reply.body.should == spec_translate(
            :new_match,
            :name => sok.name,
            :match => boy_looking_for_a_friend
          )
        end
      end
    end

    shared_examples_for "recommend sok some users to chat with" do
      before do
        send_message(:from => sok.mobile_number,:body => message_text)
      end

      context "the last message" do
        it "should have a reply" do
          last_message.reply.should be_present
        end

        context "reply" do
          it "should be sent to Sok" do
            reply.subscription.user.should == sok
          end

          it "should contain some recommendations" do
            reply.body.should == spec_translate(
              :suggestions,
              :looking_for => sok.looking_for,
              :usernames => []
            )
          end
        end
      end
    end
  end
end

