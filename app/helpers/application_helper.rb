module ApplicationHelper
  def chatable_links(resource)
    resource_name = resource.class.to_s.underscore
    capture_haml do
      [:messages, :replies, :phone_calls].each do |chatable_resources|
        chatable_resource_count = resource.send("#{chatable_resources}_count").to_i
        if chatable_resource_count.zero?
          content = chatable_resource_count
        else
          content = link_to(
            chatable_resource_count, send("#{resource_name}_interaction_path", resource)
          )
        end
        haml_tag :td, :id => chatable_resources do
          haml_concat content
        end
      end
    end
  end

  def heading_with_count(resources, count)
    capture_haml do
      haml_tag :h2, :id => "total_#{resources}" do
        haml_concat "#{resources.to_s.titleize} (#{count})"
      end
    end
  end
end
