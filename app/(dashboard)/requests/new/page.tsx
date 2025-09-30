'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createRequest } from '@/app/actions/requests'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { toast } from 'sonner'

export default function NewRequestPage() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [formData, setFormData] = useState({
    start_country: '',
    start_address: '',
    start_lat: 0,
    start_lng: 0,
    destination_country: '',
    destination_address: '',
    destination_lat: 0,
    destination_lng: 0,
    distance_km: null,
    pickup_date_from: '',
    pickup_date_to: '',
    delivery_date_from: '',
    delivery_date_to: '',
    vehicle_type: 'transporter',
    cargo_length_cm: null,
    cargo_width_cm: null,
    cargo_height_cm: null,
    cargo_weight_kg: null,
    loading_meters: null,
    requires_liftgate: false,
    requires_pallet_jack: false,
    requires_side_loading: false,
    requires_tarp: false,
    requires_gps_tracking: false,
    driver_language: 'any',
  })

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setIsLoading(true)

    try {
      const result = await createRequest(formData)

      if (result?.error) {
        toast.error(result.error)
      } else {
        toast.success('Request created successfully')
        router.push('/requests')
      }
    } catch (error) {
      toast.error('An unexpected error occurred')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">New Transport Request</h1>

      <form onSubmit={handleSubmit}>
        <div className="space-y-6">
          {/* Route Information */}
          <Card>
            <CardHeader>
              <CardTitle>Route Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Start Country *</Label>
                  <Input
                    value={formData.start_country}
                    onChange={(e) => setFormData({ ...formData, start_country: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Start Address *</Label>
                  <Input
                    value={formData.start_address}
                    onChange={(e) => setFormData({ ...formData, start_address: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Start Latitude *</Label>
                  <Input
                    type="number"
                    step="0.000001"
                    value={formData.start_lat}
                    onChange={(e) => setFormData({ ...formData, start_lat: parseFloat(e.target.value) })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Start Longitude *</Label>
                  <Input
                    type="number"
                    step="0.000001"
                    value={formData.start_lng}
                    onChange={(e) => setFormData({ ...formData, start_lng: parseFloat(e.target.value) })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Destination Country *</Label>
                  <Input
                    value={formData.destination_country}
                    onChange={(e) => setFormData({ ...formData, destination_country: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Destination Address *</Label>
                  <Input
                    value={formData.destination_address}
                    onChange={(e) => setFormData({ ...formData, destination_address: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Destination Latitude *</Label>
                  <Input
                    type="number"
                    step="0.000001"
                    value={formData.destination_lat}
                    onChange={(e) => setFormData({ ...formData, destination_lat: parseFloat(e.target.value) })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Destination Longitude *</Label>
                  <Input
                    type="number"
                    step="0.000001"
                    value={formData.destination_lng}
                    onChange={(e) => setFormData({ ...formData, destination_lng: parseFloat(e.target.value) })}
                    required
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Timing */}
          <Card>
            <CardHeader>
              <CardTitle>Timing</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Pickup Date From *</Label>
                  <Input
                    type="datetime-local"
                    value={formData.pickup_date_from}
                    onChange={(e) => setFormData({ ...formData, pickup_date_from: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label>Pickup Date To *</Label>
                  <Input
                    type="datetime-local"
                    value={formData.pickup_date_to}
                    onChange={(e) => setFormData({ ...formData, pickup_date_to: e.target.value })}
                    required
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Cargo Details */}
          <Card>
            <CardHeader>
              <CardTitle>Cargo Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Vehicle Type *</Label>
                <Select
                  value={formData.vehicle_type}
                  onValueChange={(value) => setFormData({ ...formData, vehicle_type: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="pkw">PKW</SelectItem>
                    <SelectItem value="transporter">Transporter</SelectItem>
                    <SelectItem value="lkw_749">LKW 7.49t</SelectItem>
                    <SelectItem value="lkw_1199">LKW 11.99t</SelectItem>
                    <SelectItem value="lkw_bdf">LKW BDF</SelectItem>
                    <SelectItem value="sattelzug">Sattelzug</SelectItem>
                    <SelectItem value="niederzug">Niederzug</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-4">
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="requires_liftgate"
                    checked={formData.requires_liftgate}
                    onCheckedChange={(checked) =>
                      setFormData({ ...formData, requires_liftgate: checked as boolean })
                    }
                  />
                  <Label htmlFor="requires_liftgate">Requires Liftgate</Label>
                </div>
                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="requires_pallet_jack"
                    checked={formData.requires_pallet_jack}
                    onCheckedChange={(checked) =>
                      setFormData({ ...formData, requires_pallet_jack: checked as boolean })
                    }
                  />
                  <Label htmlFor="requires_pallet_jack">Requires Pallet Jack</Label>
                </div>
              </div>
            </CardContent>
          </Card>

          <div className="flex justify-end space-x-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
              disabled={isLoading}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading ? 'Creating...' : 'Create Request'}
            </Button>
          </div>
        </div>
      </form>
    </div>
  )
}
