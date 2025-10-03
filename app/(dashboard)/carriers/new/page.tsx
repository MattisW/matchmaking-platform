'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createCarrier } from '@/app/actions/carriers'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { toast } from 'sonner'

export default function NewCarrierPage() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [formData, setFormData] = useState({
    company_name: '',
    contact_email: '',
    contact_phone: '',
    preferred_contact_method: 'email',
    language: 'de',
    country: '',
    address: '',
    lat: 0,
    lng: 0,
    pickup_radius_km: 50,
    ignore_radius: false,
    pickup_countries: [] as string[],
    delivery_countries: [] as string[],
    has_transporter: false,
    has_lkw: false,
    lkw_length_cm: null,
    lkw_width_cm: null,
    lkw_height_cm: null,
    has_liftgate: false,
    has_pallet_jack: false,
    has_gps_tracking: false,
  })

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setIsLoading(true)

    try {
      const result = await createCarrier(formData)

      if (result?.error) {
        toast.error(result.error)
      } else {
        toast.success('Carrier created successfully')
        router.push('/carriers')
      }
    } catch (error) {
      toast.error('An unexpected error occurred')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Add New Carrier</h1>
      </div>

      <form onSubmit={handleSubmit}>
        <div className="space-y-6">
          {/* Company Information */}
          <Card>
            <CardHeader>
              <CardTitle>Company Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="company_name">Company Name *</Label>
                  <Input
                    id="company_name"
                    value={formData.company_name}
                    onChange={(e) => setFormData({ ...formData, company_name: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="contact_email">Contact Email *</Label>
                  <Input
                    id="contact_email"
                    type="email"
                    value={formData.contact_email}
                    onChange={(e) => setFormData({ ...formData, contact_email: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="contact_phone">Contact Phone</Label>
                  <Input
                    id="contact_phone"
                    value={formData.contact_phone}
                    onChange={(e) => setFormData({ ...formData, contact_phone: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="language">Language</Label>
                  <Select
                    value={formData.language}
                    onValueChange={(value) => setFormData({ ...formData, language: value })}
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
              </div>
            </CardContent>
          </Card>

          {/* Location */}
          <Card>
            <CardHeader>
              <CardTitle>Location</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="country">Country *</Label>
                  <Input
                    id="country"
                    value={formData.country}
                    onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="address">Address *</Label>
                  <Input
                    id="address"
                    value={formData.address}
                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="lat">Latitude *</Label>
                  <Input
                    id="lat"
                    type="number"
                    step="0.000001"
                    value={formData.lat}
                    onChange={(e) => setFormData({ ...formData, lat: parseFloat(e.target.value) || 0 })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="lng">Longitude *</Label>
                  <Input
                    id="lng"
                    type="number"
                    step="0.000001"
                    value={formData.lng}
                    onChange={(e) => setFormData({ ...formData, lng: parseFloat(e.target.value) || 0 })}
                    required
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Fleet Capabilities */}
          <Card>
            <CardHeader>
              <CardTitle>Fleet Capabilities</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="has_transporter"
                  checked={formData.has_transporter}
                  onCheckedChange={(checked) =>
                    setFormData({ ...formData, has_transporter: checked as boolean })
                  }
                />
                <Label htmlFor="has_transporter">Has Transporter</Label>
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="has_lkw"
                  checked={formData.has_lkw}
                  onCheckedChange={(checked) =>
                    setFormData({ ...formData, has_lkw: checked as boolean })
                  }
                />
                <Label htmlFor="has_lkw">Has LKW</Label>
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="has_liftgate"
                  checked={formData.has_liftgate}
                  onCheckedChange={(checked) =>
                    setFormData({ ...formData, has_liftgate: checked as boolean })
                  }
                />
                <Label htmlFor="has_liftgate">Has Liftgate</Label>
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="has_pallet_jack"
                  checked={formData.has_pallet_jack}
                  onCheckedChange={(checked) =>
                    setFormData({ ...formData, has_pallet_jack: checked as boolean })
                  }
                />
                <Label htmlFor="has_pallet_jack">Has Pallet Jack</Label>
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
              {isLoading ? 'Creating...' : 'Create Carrier'}
            </Button>
          </div>
        </div>
      </form>
    </div>
  )
}
