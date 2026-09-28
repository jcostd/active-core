require "application_system_test_case"

# la privata scritta dal maestro sull'iPad: atleti aggiunti e tolti nel browser vero
class PrivateLessonsTest < ApplicationSystemTestCase
  ATHLETE = "input[aria-label=Atleta]"

  setup do
    sign_in "kiosk"
    click_on "Lezioni private"
    click_on "Nuova privata"
  end

  test "athletes are added and removed one by one" do
    fill_in "private_lesson[teacher]", with: "giulia esterna"
    find(ATHLETE).fill_in with: "Luca Bianchi"
    click_on "Aggiungi atleta"
    click_on "Aggiungi atleta"
    assert_selector ATHLETE, count: 3
    assert_equal "Atleta", page.active_element[:"aria-label"], "il nuovo campo prende il fuoco"

    all(ATHLETE)[1].fill_in with: "Ospite"
    all("button[aria-label='Togli atleta']").last.click
    assert_selector ATHLETE, count: 2
    find("input[type=radio][aria-label='45 min']").click
    click_on "Salva"

    assert_text "Privata di Giulia Esterna registrata."
    within("#private_lessons") do
      assert_text "Luca Bianchi"
      assert_text "Ospite"
    end
    assert_equal [ [ "Luca Bianchi", "Ospite" ], 45 ], PrivateLesson.last.values_at(:athletes, :duration_minutes)
  end

  test "the last athlete is emptied, not removed" do
    find(ATHLETE).fill_in with: "Luca"
    find("button[aria-label='Togli atleta']").click

    assert_selector ATHLETE, count: 1
    assert_equal "", find(ATHLETE).value
  end
end
