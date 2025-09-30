'use client'

import { use, useEffect, useState } from 'react'
import { submitOffer } from '@/app/actions/offers'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { toast } from 'sonner'
import { createClient } from '@/lib/supabase/client'

export default function OfferPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const [isLoading, setIsLoading] = useState(false)
  const [carrierRequest, setCarrierRequest] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [formData, setFormData] = useState({
    offered_price: '',
    offered_delivery_date: '',
    transport_type: 'solo',
    vehicle_type: '',
    driver_language: 'de',
    notes: '',
  })

  useEffect(() => {
    async function fetchData() {
      const supabase = createClient()
      const { data } = await supabase
        .from('carrier_requests')
        .select('*, transport_requests(*), carriers(*)')
        .eq('id', id)
        .single()

      setCarrierRequest(data)
      setLoading(false)
    }
    fetchData()
  }, [id])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setIsLoading(true)

    try {
      const result = await submitOffer(id, {
        ...formData,
        offered_price: parseFloat(formData.offered_price),
      })

      if (result?.error) {
        toast.error(result.error)
      } else {
        toast.success('Offer submitted successfully!')
      }
    } catch (error) {
      toast.error('An unexpected error occurred')
    } finally {
      setIsLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p>Loading...</p>
      </div>
    )
  }

  if (!carrierRequest || !carrierRequest.transport_requests) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle>Request Not Found</CardTitle>
            <CardDescription>This transport request is no longer available.</CardDescription>
          </CardHeader>
        </Card>
      </div>
    )
  }

  if (carrierRequest.transport_requests.status === 'cancelled') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle>Request Cancelled</CardTitle>
            <CardDescription>This transport request has been cancelled.</CardDescription>
          </CardHeader>
        </Card>
      </div>
    )
  }

  if (carrierRequest.status === 'offered') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle>Offer Already Submitted</CardTitle>
            <CardDescription>You have already submitted an offer for this request.</CardDescription>
          </CardHeader>
        </Card>
      </div>
    )
  }

  const request = carrierRequest.transport_requests

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4 py-8">
      <Card className="w-full max-w-2xl">
        <CardHeader>
          <CardTitle>Submit Offer</CardTitle>
          <CardDescription>
            Transport Request: {request.start_country} → {request.destination_country}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {/* Request Details */}
          <div className="mb-6 p-4 bg-gray-50 rounded-lg">
            <h3 className="font-semibold mb-2">Request Details</h3>
            <div className="space-y-1 text-sm">
              <p><span className="text-gray-500">Route:</span> {request.start_address} → {request.destination_address}</p>
              <p><span className="text-gray-500">Pickup:</span> {new Date(request.pickup_date_from).toLocaleDateString()}</p>
              <p><span className="text-gray-500">Vehicle Type:</span> {request.vehicle_type}</p>
              {request.cargo_weight_kg && (
                <p><span className="text-gray-500">Weight:</span> {request.cargo_weight_kg} kg</p>
              )}
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="offered_price">Offered Price (EUR) *</Label>
              <Input
                id="offered_price"
                type="number"
                step="0.01"
                value={formData.offered_price}
                onChange={(e) => setFormData({ ...formData, offered_price: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="offered_delivery_date">Estimated Delivery Date *</Label>
              <Input
                id="offered_delivery_date"
                type="datetime-local"
                value={formData.offered_delivery_date}
                onChange={(e) => setFormData({ ...formData, offered_delivery_date: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="transport_type">Transport Type *</Label>
              <Select
                value={formData.transport_type}
                onValueChange={(value) => setFormData({ ...formData, transport_type: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="solo">Solo</SelectItem>
                  <SelectItem value="shared">Shared</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="vehicle_type">Vehicle Type *</Label>
              <Input
                id="vehicle_type"
                value={formData.vehicle_type}
                onChange={(e) => setFormData({ ...formData, vehicle_type: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="driver_language">Driver Language *</Label>
              <Select
                value={formData.driver_language}
                onValueChange={(value) => setFormData({ ...formData, driver_language: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="de">German</SelectItem>
                  <SelectItem value="en">English</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="notes">Notes (Optional)</Label>
              <Input
                id="notes"
                value={formData.notes}
                onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
              />
            </div>

            <Button type="submit" className="w-full" disabled={isLoading}>
              {isLoading ? 'Submitting...' : 'Submit Offer'}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
