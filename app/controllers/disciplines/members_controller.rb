# chi è iscritto alla disciplina in un mese, e chi l'istruttore ha visto: la segreteria allo specchio del kiosk
class Disciplines::MembersController < ApplicationController
  include Filterable, SafeDateParsing

  before_action :set_discipline

  def index
    @month    = parse_month_param(params[:month]).beginning_of_month
    @products = @discipline.products.kept
    @editable = Attendance.editable_by?(current_user, @month)

    enrolled = Member.enrolled_in(@discipline, during: @month.all_month, product_id: params[:product_id])
                     .by_attendance(@discipline, @month, params[:seen])
    @pagy, @members = pagy(enrolled.apply_filters(filter_params).preload(subscriptions: [ :sales, { product: :disciplines } ]))

    @enrollments = @members.index_with { it.enrollments_in(@discipline, during: @month.all_month) }
    Subscription.preload_renewed(@enrollments.values.flatten)
    @attendances = @discipline.attendances.in_month(@month).where(member: @members).includes(:marked_by).index_by(&:member_id)

    @unenrolled = @discipline.attendances.in_month(@month).unenrolled
                             .joins(:member).order(members: { last_name: :asc, first_name: :asc })
                             .preload(:discipline, :marked_by, member: Standing::PRELOAD).to_a
    @products_to_sell = Attendance.products_to_sell(@unenrolled)
  end

  private
    def set_discipline
      @discipline = Discipline.find(params[:discipline_id])
    end

    def filter_params
      params.permit(:query, :sort, :membership_status, :med_cert).with_defaults(sort: "name_asc")
    end
end
