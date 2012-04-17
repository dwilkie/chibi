module ApplicationHelper
  def chatable_link(resource, chatable_resources_name)
    resource_name = resource.class.to_s.underscore
    chatable_resource_count = resource.send("#{chatable_resources_name}_count").to_i
    chatable_resource_count.zero? ? chatable_resource_count : link_to(chatable_resource_count, send("#{resource_name}_#{chatable_resources_name}_path", resource))
  end

  def heading_with_count(resources, count)
    capture_haml do
      haml_tag :h2, :id => "total_#{resources}" do
        haml_concat "#{resources.to_s.titleize} (#{count})"
      end
    end
  end
end
