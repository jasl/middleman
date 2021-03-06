module Padrino
  module Helpers
    module FormBuilder
      class AbstractFormBuilder
        attr_accessor :template, :object, :multipart

        def initialize(template, object, options={})
          @template = template
          @object   = build_object(object)
          @options  = options
          raise "FormBuilder template must be initialized!" unless template
          raise "FormBuilder object must not be a nil value. If there's no object, use a symbol instead! (i.e :user)" unless object
        end

        def error_messages(*params)
          params.unshift object
          @template.error_messages_for(*params)
        end

        def error_message_on(field, options={})
          @template.error_message_on(object, field, options)
        end

        def label(field, options={}, &block)
          options.reverse_merge!(:caption => "#{field_human_name(field)}: ")
          @template.label_tag(field_id(field), options, &block)
        end

        def hidden_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          @template.hidden_field_tag field_name(field), options
        end

        def text_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.text_field_tag field_name(field), options
        end

        def number_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.number_field_tag field_name(field), options
        end

        def telephone_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.telephone_field_tag field_name(field), options
        end
        alias_method :phone_field, :telephone_field

        def email_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.email_field_tag field_name(field), options
        end

        def search_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.search_field_tag field_name(field), options
        end

        def url_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.url_field_tag field_name(field), options
        end

        def text_area(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.text_area_tag field_name(field), options
        end

        def password_field(field, options={})
          options.reverse_merge!(:value => field_value(field), :id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.password_field_tag field_name(field), options
        end

        def select(field, options={})
          options.reverse_merge!(:id => field_id(field), :selected => field_value(field))
          options.merge!(:class => field_error(field, options))
          @template.select_tag field_name(field), options
        end

        def check_box_group(field, options={})
          selected_values = Array(options[:selected] || field_value(field))
          if options[:collection]
            fields = options[:fields] || [:name, :id]
            selected_values = selected_values.map{ |v| (v.respond_to?(fields[0]) ? v.send(fields[1]) : v).to_s }
          end
          labeled_group( field, options ) do |variant|
            @template.check_box_tag( field_name(field)+'[]', :value => variant[1], :id => variant[2], :checked => selected_values.include?(variant[1]) )
          end
        end

        def radio_button_group(field, options={})
          fields = options[:fields] || [:name, :id]
          selected_value = options[:selected] || field_value(field)
          selected_value = selected_value.send(fields[1])  if selected_value.respond_to?(fields[0])
          labeled_group( field, options ) do |variant|
            @template.radio_button_tag( field_name(field), :value => variant[1], :id => variant[2], :checked => variant[1] == selected_value.to_s )
          end
        end

        def check_box(field, options={})
          html = ActiveSupport::SafeBuffer.new
          unchecked_value = options.delete(:uncheck_value) || '0'
          options.reverse_merge!(:id => field_id(field), :value => '1')
          options.reverse_merge!(:checked => true) if values_matches_field?(field, options[:value])
          html << @template.hidden_field_tag(options[:name] || field_name(field), :value => unchecked_value, :id => nil)
          html << @template.check_box_tag(field_name(field), options)
        end

        def radio_button(field, options={})
          options.reverse_merge!(:id => field_id(field, options[:value]))
          options.reverse_merge!(:checked => true) if values_matches_field?(field, options[:value])
          @template.radio_button_tag field_name(field), options
        end

        def file_field(field, options={})
          self.multipart = true
          options.reverse_merge!(:id => field_id(field))
          options.merge!(:class => field_error(field, options))
          @template.file_field_tag field_name(field), options
        end

        def submit(*args)
          options = args[-1].is_a?(Hash) ? args.pop : {}
          caption = args.length >= 1 ? args.shift : "Submit"
          @template.submit_tag caption, options
        end

        def image_submit(source, options={})
          @template.image_submit_tag source, options
        end

        ##
        # Supports nested fields for a child model within a form.
        # f.fields_for :addresses
        # f.fields_for :addresses, address
        # f.fields_for :addresses, @addresses
        def fields_for(child_association, instance_or_collection=nil, &block)
          default_collection = self.object.send(child_association)
          include_index = default_collection.respond_to?(:each)
          nested_options = { :parent => self, :association => child_association }
          nested_objects = instance_or_collection ? Array(instance_or_collection) : Array(default_collection)
          nested_objects.each_with_index.map do |child_instance, index|
            nested_options[:index] = include_index ? index : nil
            @template.fields_for(child_instance,  { :nested => nested_options }, &block)
          end.join("\n").html_safe
        end

        def csrf_token_field
          @template.csrf_token_field
        end

        protected
        # Returns the known field types for a Formbuilder.
        def self.field_types
          [:hidden_field, :text_field, :text_area, :password_field, :file_field, :radio_button, :check_box, :select]
        end

        ##
        # Returns true if the value matches the value in the field.
        # field_has_value?(:gender, 'male')
        def values_matches_field?(field, value)
          value.present? && (field_value(field).to_s == value.to_s || field_value(field).to_s == 'true')
        end

        ##
        # Add a :invalid css class to the field if it contain an error.
        #
        def field_error(field, options)
          error = @object.errors[field] rescue nil
          error.blank? ? options[:class] : [options[:class], :invalid].flatten.compact.join(" ")
        end

        ##
        # Returns the human name of the field. Look that use builtin I18n.
        #
        def field_human_name(field)
          I18n.translate("#{object_model_name}.attributes.#{field}", :count => 1, :default => field.to_s.humanize, :scope => :models)
        end

        ##
        # Returns the name for the given field.
        # field_name(:username) => "user[username]"
        # field_name(:number) => "user[telephone_attributes][number]"
        # field_name(:street) => "user[addresses_attributes][0][street]"
        def field_name(field=nil)
          result = field_result
          result << field_name_fragment if nested_form?
          result << "[#{field}]" unless field.blank?
          result.flatten.join
        end

        ##
        # Returns the id for the given field.
        # field_id(:username) => "user_username"
        # field_id(:gender, :male) => "user_gender_male"
        # field_name(:number) => "user_telephone_attributes_number"
        # field_name(:street) => "user_addresses_attributes_0_street"
        def field_id(field=nil, value=nil)
          result = []
          result << "#{@options[:namespace]}_" if @options[:namespace] && root_form?
          result << field_result
          result << field_id_fragment if nested_form?
          result << "_#{field}" unless field.blank?
          result << "_#{value}" unless value.blank?
          result.flatten.join
        end

        ##
        # Returns the child object if it exists.
        #
        def nested_object_id
          nested_form? && object.respond_to?(:new_record?) && !object.new_record? && object.id
        end

        ##
        # Returns true if this form object is nested in a parent form.
        #
        def nested_form?
          @options[:nested] && @options[:nested][:parent] && @options[:nested][:parent].respond_to?(:object)
        end

        ##
        # Returns the value for the object's field.
        #
        def field_value(field)
          @object && @object.respond_to?(field) ? @object.send(field) : ""
        end

        ##
        # Returns a new record of the type specified in the object
        #
        def build_object(object_or_symbol)
          object_or_symbol.is_a?(Symbol) ? @template.instance_variable_get("@#{object_or_symbol}") || object_class(object_or_symbol).new : object_or_symbol
        end

        ##
        # Returns the object's models name.
        #
        def object_model_name(explicit_object=object)
          explicit_object.is_a?(Symbol) ? explicit_object : explicit_object.class.to_s.underscore.gsub(/\//, '_')
        end

        ##
        # Returns the class type for the given object.
        #
        def object_class(explicit_object)
          explicit_object.is_a?(Symbol) ? explicit_object.to_s.camelize.constantize : explicit_object.class
        end

        ##
        # Returns true if this form is the top-level (not nested).
        #
        def root_form?
          !nested_form?
        end

        ##
        # Builds a group of labels for radios or checkboxes.
        #
        def labeled_group(field, options={})
          options.reverse_merge!(:id => field_id(field), :selected => field_value(field))
          options.merge!(:class => field_error(field, options))
          variants = case
          when options[:options]
            options[:options].map{ |caption, value| [caption.to_s, (value||caption).to_s] }
          when options[:collection]
            fields = options[:fields] || [:name, :id]
            options[:collection].map{ |variant| [variant.send(fields.first).to_s, variant.send(fields.last).to_s] }
          else
            []
          end
          variants.inject(''.html_safe) do |html, variant|
            variant[2] = "#{field_id(field)}_#{variant[1]}"
            html << @template.label_tag("#{field_name(field)}[]", :for => variant[2], :caption => "#{yield(variant)} #{variant[0]}")
          end
        end

        private

        def field_result
          result = []
          result << object_model_name if root_form?
          result
        end

        def field_name_fragment
          fragment = [result_options[:parent_form].field_name, "[#{result_options[:attributes_name]}", "]"]
          fragment.insert(2, "][#{result_options[:nested_index]}") if result_options[:nested_index]
          fragment
        end

        def field_id_fragment
          fragment = [result_options[:parent_form].field_id, "_#{result_options[:attributes_name]}"]
          fragment.push("_#{result_options[:nested_index]}") if result_options[:nested_index]
          fragment
        end

        def result_options
          {
            :parent_form  => @options[:nested][:parent],
            :nested_index => @options[:nested][:index],
            :attributes_name => "#{@options[:nested][:association]}_attributes"
          }
        end
      end
    end
  end
end
