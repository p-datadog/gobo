require 'spec_helper'
require 'will_paginate'
require 'will_paginate/collection'
require_relative '../../lib/bootstrap5_pagination_renderer'

RSpec.describe Bootstrap5PaginationRenderer do
  # A minimal stand-in for an ActionView template that implements only the
  # methods the renderer calls: +url_for+ (to build page URLs) and
  # +will_paginate_translate+ (to resolve labels and aria text). It does not
  # respond to +request+, so the renderer skips GET-param merging.
  let(:template) do
    Class.new do
      def url_for(params)
        "/?page=#{params[:page]}"
      end

      def will_paginate_translate(_key, _options = {})
        yield
      end
    end.new
  end

  def render_pagination(collection)
    options = WillPaginate::ViewHelpers.pagination_options.merge(param_name: :page)
    options[:previous_label] ||= template.will_paginate_translate(:previous_label) { '&#8592; Previous' }
    options[:next_label]     ||= template.will_paginate_translate(:next_label) { 'Next &#8594;' }
    renderer = described_class.new
    renderer.prepare(collection, options, template)
    renderer.to_html
  end

  let(:collection) { WillPaginate::Collection.new(2, 2, 10) } # current page 2 of 5

  it 'wraps the links in a nav with aria-label and a ul.pagination' do
    html = render_pagination(collection)
    expect(html).to include('<nav aria-label="Pagination">')
    expect(html).to include('<ul class="pagination">')
    expect(html).to include('</ul></nav>')
  end

  it 'renders each page as a page-item with a page-link' do
    html = render_pagination(collection)
    expect(html).to include('class="page-item"')
    expect(html).to include('class="page-link"')
  end

  it 'marks the current page as active with aria-current="page"' do
    html = render_pagination(collection)
    expect(html).to include('class="page-item active"')
    expect(html).to include('aria-current="page"')
  end

  it 'links non-current pages to their page URL' do
    html = render_pagination(collection)
    expect(html).to include('href="/?page=1"')
    expect(html).to include('href="/?page=3"')
  end

  it 'renders a disabled gap item when the page window is truncated' do
    large = WillPaginate::Collection.new(10, 2, 40) # current page 10 of 20
    html = render_pagination(large)
    expect(html).to match(/class="page-item disabled"><span class="page-link">/)
  end

  it 'renders a disabled previous item on the first page' do
    first_page = WillPaginate::Collection.new(1, 2, 10) # page 1 of 5
    html = render_pagination(first_page)
    expect(html).to include('class="page-item disabled"')
    expect(html).to include('aria-disabled="true"')
  end

  it 'renders a disabled next item on the last page' do
    last_page = WillPaginate::Collection.new(5, 2, 10) # page 5 of 5
    html = render_pagination(last_page)
    expect(html).to include('class="page-item disabled"')
    expect(html).to include('aria-disabled="true"')
  end
end
