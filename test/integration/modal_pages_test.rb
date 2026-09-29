require "test_helper"

# le pagine dei form si aprono in modale dal frame "modal" e come pagine normali dal loro URL
class ModalPagesTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:admin)) }

  FORMS = {
    "nuovo socio"       => ->(t) { t.new_member_path },
    "modifica socio"    => ->(t) { t.edit_member_path(t.members(:alice)) },
    "nuovo prodotto"    => ->(t) { t.new_product_path },
    "nuova disciplina"  => ->(t) { t.new_discipline_path },
    "modifica utente"   => ->(t) { t.edit_user_path(t.users(:staff)) },
    "dati ASD"          => ->(t) { t.edit_gym_profile_path },
    "POS"               => ->(t) { t.new_sale_path },
    "segnalazione"      => ->(t) { t.new_feedback_path }
  }

  FORMS.each do |name, path|
    test "#{name} opens as a modal from the modal frame" do
      get path.(self), headers: { "Turbo-Frame" => "modal" }

      assert_response :success
      assert_select "turbo-frame#modal > dialog.modal[data-controller=dialog]", 1
      assert_select "dialog .modal-box form"
      assert_select "dialog > form.modal-backdrop[method=dialog]"
      assert_select "dialog .modal-box > form[method=dialog] button[aria-label=Chiudi]"
      assert_select "aside", { count: 0 }, "solo il frame, niente layout"
    end

    test "#{name} opens as a full page from its URL" do
      get path.(self)

      assert_response :success
      assert_select "aside nav" # barra laterale dell'app
      assert_select "main .card form"
      assert_select "main dialog.modal", count: 0
      assert_select "title", text: /\A[^<>]+\z/
    end
  end

  test "every page has one empty modal frame, kept out of live refreshes" do
    get root_path

    assert_select "turbo-frame#modal[data-turbo-permanent]", 1
    assert_select "turbo-frame#modal *", count: 0
    assert_select "turbo-frame#feedback_modal", count: 0
    assert_select "a[href^='/feedbacks/new'][data-turbo-frame=modal]"
  end

  test "validation errors come back inside the modal" do
    patch member_path(members(:alice)), params: { member: { last_name: "" } }, headers: { "Turbo-Frame" => "modal" }, as: :html

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal > dialog.modal form"
  end

  test "a save from the modal refreshes the page, a save from the full page redirects" do
    patch member_path(members(:alice)), params: { member: { phone: "3339998888" } }, headers: { "Turbo-Frame" => "modal" }, as: :turbo_stream
    assert_select "turbo-stream[action=refresh]"

    patch member_path(members(:alice)), params: { member: { phone: "3331112222" } }
    assert_redirected_to member_path(members(:alice))
    assert_equal "Socio aggiornato con successo.", flash[:notice]
  end

  test "the feedback modal refreshes the page with a thank you" do
    post feedbacks_path, params: { feedback: { message: "Stampa lenta", page_url: "/members" } }, as: :turbo_stream

    assert_select "turbo-stream[action=refresh]"
    assert_equal "Segnalazione inviata. Grazie per il tuo aiuto!", flash[:notice]
  end

  test "the page title is plain text even when the form title has icons" do
    get new_feedback_path
    assert_select "title", text: "Feedback & Supporto"
  end
end
