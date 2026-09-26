require "test_helper"

class DisciplinesControllerTest < ActionDispatch::IntegrationTest
  test "staff sees index and show" do
    sign_in_as(users(:staff))
    get disciplines_path
    assert_response :success
    assert_no_match ">Pilates<", response.body

    get discipline_path(disciplines(:yoga))
    assert_response :success
  end

  test "admin creates, updates and archives" do
    sign_in_as(users(:admin))

    post disciplines_path, params: { discipline: { name: "boxe thai", requires_medical_certificate: "1", requires_membership: "0" } }
    boxe = Discipline.find_by!(name: "Boxe Thai")
    assert boxe.requires_medical_certificate?
    assert_not boxe.requires_membership?

    patch discipline_path(boxe), params: { discipline: { requires_membership: "1" } }
    assert boxe.reload.requires_membership?

    delete discipline_path(boxe)
    assert boxe.reload.discarded?
  end

  test "duplicate name is rejected" do
    sign_in_as(users(:admin))
    post disciplines_path, params: { discipline: { name: "yoga" } }
    assert_response :unprocessable_entity
  end

  test "discipline members registry with filters" do
    member = members(:alice)
    grant_membership_to(member)
    course = link!(products(:yoga_monthly), disciplines(:yoga))
    sell!(member:, product: course)
    sign_in_as(users(:staff))

    get discipline_members_path(disciplines(:yoga))
    assert_response :success
    assert_match "Alice Allevi", response.body

    get discipline_members_path(disciplines(:yoga), med_cert: "expired")
    assert_no_match "Alice Allevi", response.body
  end
end
