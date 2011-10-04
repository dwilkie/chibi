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

  context "Sok is looking for a friend" do
    context "and there are users in the system", :search => true do
      def reload_index_and_commit(reload_instances)
        reload_instances.each do |instance|
          instance.reload.index
        end

        Sunspot.commit
      end

      before(:all) do
        reload_index_and_commit(users)
      end

      context "when he searches" do
        before(:all) do
          search(sok)
        end

        it "should match him with the boy looking for a friend" do
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

