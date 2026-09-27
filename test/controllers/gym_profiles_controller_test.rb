require "test_helper"

class GymProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:admin)) }

  test "admin edits the association data" do
    get edit_gym_profile_path
    assert_response :success
    assert_select "input[name='gym_profile[name]'][value='#{GymProfile.current.name}']"

    patch gym_profile_path, params: { gym_profile: { name: "A.S.D. Querini Fit", vat_number: "94103620277",
                                                     city: "venezia", bank_iban: "IT11 A050 3402 0700 0000 0010 114" } }

    assert_redirected_to edit_gym_profile_path
    profile = GymProfile.current
    assert_equal [ "A.S.D. Querini Fit", "94103620277", "Venezia" ], [ profile.name, profile.vat_number, profile.city ]
  end

  test "invalid data re-renders the form in italian" do
    patch gym_profile_path, params: { gym_profile: { name: "", vat_number: "123" } }

    assert_response :unprocessable_entity
    assert_match "Denominazione non può essere lasciato in bianco", response.body
    assert_match "Codice fiscale / P.IVA deve avere 11 cifre o 16 caratteri", response.body
    assert GymProfile.current.name.present?
  end

  test "the receipt prints the updated data" do
    patch gym_profile_path, params: { gym_profile: { name: "A.S.D. Querini Fit", vat_number: "94103620277" } }
    grant_membership_to(members(:alice))
    sale = sell!(member: members(:alice), product: products(:yoga_monthly))

    get sale_path(sale, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "the sidebar links the page for admins only" do
    get root_path
    assert_select "a[href='#{edit_gym_profile_path}']"

    sign_in_as(users(:staff))
    get root_path
    assert_select "a[href='#{edit_gym_profile_path}']", count: 0
  end

  test "there is always a single profile" do
    assert_no_difference -> { GymProfile.count } do
      patch gym_profile_path, params: { gym_profile: { name: "Altra" } }
    end
  end
end
