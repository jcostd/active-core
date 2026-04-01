# frozen_string_literal: true

class Pagy
  module NumericHelpers
    private

    def daisyui_html_for(which, a_lambda)
      base_classes = "join-item btn bg-base-100 border-base-300 text-base-content/70 hover:bg-base-200 hover:text-base-content"

      if send(which)
        a_lambda.(send(which), I18n.translate("pagy.#{which}"),
                  classes:    base_classes,
                  aria_label: I18n.translate("pagy.aria_label.#{which}"))
      else
        %(<a role="link" class="join-item btn btn-disabled bg-base-100 border-base-300 text-base-content/30" aria-disabled="true" aria-label="#{
        I18n.translate("pagy.aria_label.#{which}")}">#{I18n.translate("pagy.#{which}")}</a>)
      end
    end

    def daisyui_series_nav(classes: "join", **)
      a_lambda = a_lambda(**)

      html = %(<div class="#{classes}">#{daisyui_html_for(:previous, a_lambda)})
      series(**).each do |item|
        html << case item
        when Integer
                  # Normal page links
                  a_lambda.(item, classes: "join-item btn bg-base-100 border-base-300 text-base-content/70 hover:bg-base-200 hover:text-base-content")
        when String
                  # Active page
                  %(<a role="link" class="join-item btn btn-active !bg-base-content !text-base-100 !border-base-content" aria-current="page" aria-disabled="true">#{page_label(item)}</a>)
        when :gap
                  # Gap (...)
                  %(<a role="link" class="join-item btn btn-disabled bg-base-100 border-base-300 text-base-content/30" aria-disabled="true">#{I18n.translate('pagy.gap')}</a>)
        else raise InternalError, "expected item types in series to be Integer, String or :gap; got #{item.inspect}"
        end
      end
      html << %(#{daisyui_html_for(:next, a_lambda)}</div>)

      wrap_series_nav(html, "pagy-daisyui series-nav", **)
    end

    def daisyui_series_nav_js(classes: "join", **)
      a_lambda = a_lambda(**)

      tokens   = { before:  %(<div class="#{classes}">#{daisyui_html_for(:previous, a_lambda)}),
                   anchor:  a_lambda.(PAGE_TOKEN, LABEL_TOKEN, classes: "join-item btn bg-base-100 border-base-300 text-base-content/70 hover:bg-base-200 hover:text-base-content"),
                   current: %(<a role="link" class="join-item btn btn-active !bg-base-content !text-base-100 !border-base-content" aria-current="page" aria-disabled="true">#{LABEL_TOKEN}</a>),
                   gap:     %(<a role="link" class="join-item btn btn-disabled bg-base-100 border-base-300 text-base-content/30" aria-disabled="true">#{I18n.translate('pagy.gap')}</a>),
                   after:   %(#{daisyui_html_for(:next, a_lambda)}</div>) }

      wrap_series_nav_js(tokens, "pagy-daisyui series-nav-js", **)
    end

    def daisyui_input_nav_js(classes: "join", **)
      a_lambda = a_lambda(**)

      input    = %(<input name="page" type="number" min="1" max="#{last}" value="#{@page}" aria-current="page" ) +
                 %(class="join-item input input-bordered bg-base-100 border-base-300 text-base-content text-center p-0" style="width: #{@page.to_s.length + 3}rem;">#{A_TAG})

      html     = %(<div class="#{classes}">#{
                   daisyui_html_for(:previous, a_lambda)
                   }<span class="join-item btn btn-disabled bg-base-100 border-base-300 text-base-content/70 font-normal cursor-default">#{
                   I18n.translate('pagy.input_nav_js', page_input: input, pages: @last)
                   }</span>#{
                   daisyui_html_for(:next, a_lambda)
                   }</div>)

      wrap_input_nav_js(html, "pagy-daisyui input-nav-js", **)
    end
  end
end
