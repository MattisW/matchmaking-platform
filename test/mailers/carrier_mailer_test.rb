require "test_helper"

class CarrierMailerTest < ActionMailer::TestCase
  test "invitation" do
    mail = CarrierMailer.invitation
    assert_equal "Invitation", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "offer_accepted" do
    mail = CarrierMailer.offer_accepted
    assert_equal "Offer accepted", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "offer_rejected" do
    mail = CarrierMailer.offer_rejected
    assert_equal "Offer rejected", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
