module ApplicationHelper
  def present(object_or_name, klass = nil)
    if object_or_name.is_a?(Symbol) || object_or_name.is_a?(String)
      class_name = object_or_name.to_s.classify
    else
      object = object_or_name
      class_name = object.class
    end
    klass ||= "#{class_name}Presenter".constantize
    presenter = klass.new(object, self)
    yield presenter if block_given?
    presenter
  end

  def communicable_links(resource)
    resource_name = resource.class.to_s.underscore
    capture_haml do
      resource.class.communicable_resources.each do |communicable_resources|
        communicable_resource_count = resource.send(communicable_resources).size.to_i
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
