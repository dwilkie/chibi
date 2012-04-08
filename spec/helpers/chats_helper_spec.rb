require 'spec_helper'

describe ChatsHelper do
  let(:chat) { create(:chat) }

  describe "#chatable_link" do

    def assert_chatable_link(chatable_resources)
      reference_chat = Chat.filter_by.first
      helper.chatable_link(reference_chat, chatable_resources).should == 0
      create(chatable_resources.to_s.singularize, :chat => chat)
      reference_chat = Chat.filter_by.first
      helper.chatable_link(reference_chat, chatable_resources).should have_link(
        "1", :href => "/chats/#{chat.id}/#{chatable_resources}"
      )
    end

    before do
      chat
    end

    it "should return a link for the chatable resource" do
      CHATABLE_RESOURCES.each do |chatable_resources|
        assert_chatable_link(chatable_resources)
      end
    end
  end

  describe "#chat_user_link" do

    let(:active_chat_with_single_user) { create(:active_chat_with_single_user) }

    def assert_chat_user_link(reference_chat, user_type, options = {})
      result = helper.chat_user_link(reference_chat, user_type)
      if options[:link] == false
        result.should == "-"
      else
        reference_user = reference_chat.send(user_type)
        result.should have_link(
          reference_user.screen_id,
          :href => "/users/#{reference_user.id}"
        )
      end
    end

    it "should return a link for the chat user" do
      assert_chat_user_link(chat, :inactive_user, :link => false)

      USER_TYPES_IN_CHAT.each do |user_type|
        assert_chat_user_link(active_chat_with_single_user, user_type)
      end
    end
  end
end
