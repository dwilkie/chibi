require 'spec_helper'

describe ApplicationHelper do

  describe "#chatable_link" do
    def assert_chatable_link(resource_class, resource_name, chatable_resources)
      reference_resource = resource_class.filter_by.first
      helper.chatable_link(reference_resource, chatable_resources).should == 0
      resource = create(resource_name)
      create(chatable_resources.to_s.singularize, resource_name => resource)
      reference_resource = resource_class.filter_by.first
      helper.chatable_link(reference_resource, chatable_resources)
      helper.chatable_link(reference_resource, chatable_resources).should have_link(
        "1", :href => "/#{resource_name.to_s.pluralize}/#{resource.id}/#{chatable_resources}"
      )
    end

    it "should return a link for the chatable resource" do
      [User, Chat].each do |resource_class|
        resource_name = resource_class.to_s.underscore.to_sym
        create(resource_name)
        CHATABLE_RESOURCES.each do |chatable_resources|
          assert_chatable_link(resource_class, resource_name, chatable_resources)
        end
      end
    end
  end

  describe "#heading_with_count" do
    before do
      helper.extend Haml
      helper.extend Haml::Helpers
      helper.send :init_haml_helpers
    end

    it "should return a h2 heading with the resource and the count" do
      helper.heading_with_count(:phone_calls, 5).should have_css(
        "h2#total_phone_calls", :text => "Phone Calls (5)"
      )
    end
  end
end
