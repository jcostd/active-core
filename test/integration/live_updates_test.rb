require "test_helper"

# aggiornamenti in tempo reale (Solid Cable): la pagina si ricompone con morph e mantiene lo scroll,
# e ogni pagina ascolta solo i flussi che la riguardano
class LiveUpdatesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @yoga = disciplines(:yoga)
    sign_in_as(users(:staff))
  end

  test "app and kiosk refresh by morphing and keep the scroll" do
    [ root_path, discipline_members_path(@yoga), kiosk_discipline_path(@yoga) ].each do |path|
      get path
      assert_select "head meta[name='turbo-refresh-method'][content='morph']", 1, path
      assert_select "head meta[name='turbo-refresh-scroll'][content='preserve']", 1, path
    end
  end

  test "discipline pages follow their own register, the dashboard all of them" do
    get discipline_members_path(@yoga)
    assert_equal [ stream(@yoga, :attendances), stream("members") ].sort, streams.sort

    get kiosk_discipline_path(@yoga)
    assert_equal [ stream(@yoga, :attendances), stream("members") ].sort, streams.sort

    get root_path
    assert_includes streams, stream("attendances")
    assert_not_includes streams, stream("subscriptions"), "nessun modello trasmette su subscriptions"
  end

  test "a mark is broadcast to its discipline and to the dashboard, not to other disciplines" do
    assert_turbo_stream_broadcasts([ @yoga, :attendances ]) do
      assert_turbo_stream_broadcasts("attendances") do
        assert_no_turbo_stream_broadcasts([ disciplines(:sala_pesi), :attendances ]) do
          perform_enqueued_jobs { Attendance.create!(member: members(:alice), discipline: @yoga, marked_by: users(:kiosk)) }
        end
      end
    end
  end

  test "a sale refreshes the pages listening to members" do
    grant_membership_to(members(:alice))

    assert_turbo_stream_broadcasts("members") do
      perform_enqueued_jobs { sell!(member: members(:alice), product: link!(products(:yoga_monthly), @yoga)) }
    end
  end

  private
    def streams = css_select("turbo-cable-stream-source").map { it["signed-stream-name"] }

    def stream(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)
end
