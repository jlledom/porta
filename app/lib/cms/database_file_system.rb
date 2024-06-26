# frozen_string_literal: true

# A liquid template lookup for 3scale buyer side partial rendering.
# That is, whenever you use the `{% include 'menu' %}`.
#
class CMS::DatabaseFileSystem < Liquid::BlankFileSystem
  EMPTY_STRING = ''

  attr_reader :provider, :history

  def initialize(provider, lookup_context)
    @provider = provider
    @lookup_context = lookup_context
    @history = []
  end

  def read_template_file(template_path, context)
    raise ArgumentError, "Cannot find partial without name." unless template_path

    draft = context.registers[:draft]
    partial = find_partial(template_path)
    partial ? partial.content(draft) : partial_from_filesystem(template_path, context)
  end

  def find_portlet(path)
    record @provider.portlets.find_by(system_name: path)
  end

  def find_partial(path)
    record @provider.all_partials.find_by(system_name: path)
  end

  def partial_from_filesystem(path, context)
    renderer = LiquidPartialRenderer.new(@lookup_context)
    template = renderer.find_template(path)
    template.source
  rescue ActionView::MissingTemplate
    Rails.logger.error("MissingTemplate: #{path}")
    EMPTY_STRING
  end

  private

  class LiquidPartialRenderer < ActionView::PartialRenderer
    def initialize(lookup_context, options = {})
      super(lookup_context, options)
      @details = { formats: [:html], handlers: [:liquid] }
    end

    def find_template(path, locals = [])
      super(path, locals)
    end
  end

  def record(template)
    @history << template if template
    template
  end

end
