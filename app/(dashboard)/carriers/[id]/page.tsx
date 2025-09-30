import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

export default async function CarrierDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()

  const { data: carrier } = await supabase
    .from('carriers')
    .select('*')
    .eq('id', id)
    .single()

  if (!carrier) {
    notFound()
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">{carrier.company_name}</h1>
        <div className="flex gap-2">
          <Link href={`/carriers/${id}/edit`}>
            <Button variant="outline">Edit</Button>
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Company Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div>
              <p className="text-sm text-gray-500">Email</p>
              <p className="font-medium">{carrier.contact_email}</p>
            </div>
            {carrier.contact_phone && (
              <div>
                <p className="text-sm text-gray-500">Phone</p>
                <p className="font-medium">{carrier.contact_phone}</p>
              </div>
            )}
            <div>
              <p className="text-sm text-gray-500">Language</p>
              <p className="font-medium">{carrier.language}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Status</p>
              {carrier.blacklisted ? (
                <Badge variant="destructive">Blacklisted</Badge>
              ) : (
                <Badge>Active</Badge>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Location</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div>
              <p className="text-sm text-gray-500">Address</p>
              <p className="font-medium">{carrier.address}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Country</p>
              <p className="font-medium">{carrier.country}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Coordinates</p>
              <p className="font-medium">
                {carrier.lat}, {carrier.lng}
              </p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Fleet Capabilities</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div className="flex flex-wrap gap-2">
              {carrier.has_transporter && <Badge>Transporter</Badge>}
              {carrier.has_lkw && <Badge>LKW</Badge>}
              {carrier.has_liftgate && <Badge>Liftgate</Badge>}
              {carrier.has_pallet_jack && <Badge>Pallet Jack</Badge>}
              {carrier.has_gps_tracking && <Badge>GPS Tracking</Badge>}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Service Area</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div>
              <p className="text-sm text-gray-500">Pickup Radius</p>
              <p className="font-medium">
                {carrier.ignore_radius ? 'Unlimited' : `${carrier.pickup_radius_km} km`}
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
