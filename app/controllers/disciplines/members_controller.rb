# chi è iscritto alla disciplina in un mese: gli stessi soci che il kiosk propone all'appello
class Disciplines::MembersController < ApplicationController
  include Filterable, SafeDateParsing

  before_action :set_discipline

  def index
    @month    = parse_month_param(params[:month])
    @products = @discipline.products.kept

    enrolled = Member.enrolled_in(@discipline, during: @month.all_month, product_id: params[:product_id])
    @pagy, @members = pagy(enrolled.apply_filters(filter_params).preload(subscriptions: [ :sales, { product: :disciplines } ]))

    @enrollments = @members.index_with { it.enrollments_in(@discipline, during: @month.all_month) }
    Subscription.preload_renewed(@enrollments.values.flatten)
    @presences = @discipline.access_logs.where(member: @members, entered_at: @month.in_time_zone.all_month).group(:member_id).count
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:discipline_id])
    end

    def filter_params
      params.permit(:query, :sort, :membership_status, :med_cert).with_defaults(sort: "name_asc")
    end
end
