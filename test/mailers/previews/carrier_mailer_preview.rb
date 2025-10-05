# Preview all emails at http://localhost:3000/rails/mailers/carrier_mailer
class CarrierMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/carrier_mailer/invitation
  def invitation
    CarrierMailer.invitation
  end

  # Preview this email at http://localhost:3000/rails/mailers/carrier_mailer/offer_accepted
  def offer_accepted
    CarrierMailer.offer_accepted
  end

  # Preview this email at http://localhost:3000/rails/mailers/carrier_mailer/offer_rejected
  def offer_rejected
    CarrierMailer.offer_rejected
  end
end
