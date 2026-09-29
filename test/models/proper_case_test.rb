require "test_helper"

class ProperCaseTest < ActiveSupport::TestCase
  test "person capitalizes lowercase and uppercase words" do
    assert_equal "Mario Rossi", ProperCase.person("mario rossi")
    assert_equal "Mario Rossi", ProperCase.person("MARIO ROSSI")
    assert_equal "Mario Rossi", ProperCase.person("mario ROSSI")
    assert_equal "De Luca", ProperCase.person("de luca")
  end

  test "person capitalizes after apostrophes" do
    assert_equal "D'Amico", ProperCase.person("d'amico")
    assert_equal "D'Amico", ProperCase.person("D'AMICO")
    assert_equal "D'Amico", ProperCase.person("D'amico")
    assert_equal "Dell'Orto", ProperCase.person("dell'orto")
    assert_equal "D’Angelo", ProperCase.person("d’angelo")
    assert_equal "O'Neill", ProperCase.person("o'neill")
  end

  test "person capitalizes after hyphens" do
    assert_equal "Anna-Maria", ProperCase.person("anna-maria")
    assert_equal "Maria-Grazia", ProperCase.person("MARIA-GRAZIA")
  end

  test "person keeps intentional mixed case" do
    assert_equal "McDonald", ProperCase.person("McDonald")
    assert_equal "DiCaprio", ProperCase.person("DiCaprio")
    assert_equal "LaRosa", ProperCase.person("LaRosa")
  end

  test "person handles accented and non latin-1 letters" do
    assert_equal "Élodie", ProperCase.person("élodie")
    assert_equal "Ștefan Łukasiewicz", ProperCase.person("ȘTEFAN łukasiewicz")
    assert_equal "Niccolò", ProperCase.person("NICCOLÒ")
  end

  test "person squishes spaces and turns blank into nil" do
    assert_equal "Mario Rossi", ProperCase.person("  mario    rossi  ")
    assert_nil ProperCase.person("   ")
    assert_nil ProperCase.person(nil)
  end

  test "person does not treat roman looking names as numerals" do
    assert_equal "Vi", ProperCase.person("vi")
    assert_equal "Ivi", ProperCase.person("IVI")
  end

  test "place keeps roman numerals uppercase" do
    assert_equal "Via XX Settembre", ProperCase.place("via xx settembre")
    assert_equal "Via XX Settembre", ProperCase.place("VIA XX SETTEMBRE")
    assert_equal "Piazza Pio XII", ProperCase.place("piazza pio xii")
    assert_equal "Via IV Novembre", ProperCase.place("via iv novembre")
    assert_equal "Via I Maggio", ProperCase.place("via i maggio")
  end

  test "place capitalizes civic letters and apostrophes" do
    assert_equal "Via Roma 12/A", ProperCase.place("via roma 12/a")
    assert_equal "Via Dell'Orto 3", ProperCase.place("via dell'orto 3")
    assert_equal "Reggio Nell'Emilia", ProperCase.place("reggio nell'emilia")
  end

  test "place keeps mixed case and words that only look roman" do
    assert_equal "Via De' Medici", ProperCase.place("via de' medici")
    assert_equal "Vicolo Mix", ProperCase.place("vicolo mix")
    assert_equal "Corso DiVittorio", ProperCase.place("corso DiVittorio")
  end

  test "place turns blank into nil" do
    assert_nil ProperCase.place("  ")
    assert_nil ProperCase.place(nil)
  end

  test "title capitalizes lowercase words only" do
    assert_equal "Yoga Mensile", ProperCase.title("yoga mensile")
    assert_equal "Kick-Boxing", ProperCase.title("kick-boxing")
    assert_equal "Karate II Livello", ProperCase.title("karate ii livello")
  end

  test "title keeps acronyms and brand casing" do
    assert_equal "MMA", ProperCase.title("MMA")
    assert_equal "CrossFit Open", ProperCase.title("CrossFit open")
    assert_equal "Corso MMA Avanzato", ProperCase.title("corso MMA avanzato")
    assert_equal "YOGA", ProperCase.title("YOGA")
  end

  test "title keeps underscores and squishes spaces" do
    assert_equal "Pilates_id", ProperCase.title("pilates_id")
    assert_equal "Abbonamento Open", ProperCase.title("  abbonamento   open ")
    assert_nil ProperCase.title(" ")
  end
end
