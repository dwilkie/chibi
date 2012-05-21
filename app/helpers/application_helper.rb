module ApplicationHelper
  def communicable_links(resource)
    resource_name = resource.class.to_s.underscore
    capture_haml do
      resource.class::COMMUNICABLE_RESOURCES.each do |communicable_resources|
        communicable_resource_count = resource.send("#{communicable_resources}_count").to_i
        if communicable_resource_count.zero?
          content = communicable_resource_count
        else
          content = link_to(
            communicable_resource_count, send("#{resource_name}_interaction_path", resource)
          )
        end
        haml_tag :td, :id => communicable_resources do
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
