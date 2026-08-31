require 'action_view'
require 'will_paginate/view_helpers/action_view'

# Renders will_paginate pagination links with Bootstrap 5 markup:
#
#   <nav aria-label="Pagination">
#     <ul class="pagination">
#       <li class="page-item"><a class="page-link" href="...?page=1">1</a></li>
#       <li class="page-item active" aria-current="page"><a class="page-link" href="#">2</a></li>
#       <li class="page-item disabled"><span class="page-link">&hellip;</span></li>
#     </ul>
#   </nav>
#
# Pass it as the +renderer+ option to the +will_paginate+ helper:
#
#   <%= will_paginate @users, renderer: Bootstrap5PaginationRenderer %>
class Bootstrap5PaginationRenderer < WillPaginate::ActionView::LinkRenderer
  protected

  def html_container(html)
    aria_label = @template.will_paginate_translate(:container_aria_label) { 'Pagination' }
    tag(:nav, tag(:ul, html, class: 'pagination'), 'aria-label': aria_label)
  end

  def page_number(page)
    aria_label = @template.will_paginate_translate(:page_aria_label, page: page.to_i) { "Page #{page}" }
    if page == current_page
      tag(:li,
          tag(:a, page, class: 'page-link', href: '#', 'aria-label': aria_label),
          class: 'page-item active', 'aria-current': 'page')
    else
      tag(:li,
          link(page, page, class: 'page-link', 'aria-label': aria_label),
          class: 'page-item')
    end
  end

  def gap
    text = @template.will_paginate_translate(:page_gap) { '&hellip;' }
    tag(:li, tag(:span, text, class: 'page-link'), class: 'page-item disabled')
  end

  def previous_or_next_page(page, text, classname)
    if page
      tag(:li, link(text, page, class: 'page-link'), class: 'page-item')
    else
      tag(:li,
          tag(:span, text, class: 'page-link', 'aria-disabled': true),
          class: 'page-item disabled')
    end
  end
end
