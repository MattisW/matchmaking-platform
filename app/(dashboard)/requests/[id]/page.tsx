import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { runMatching } from '@/app/actions/matching'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

export default async function RequestDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()

  const { data: request } = await supabase
    .from('transport_requests')
    .select('*')
    .eq('id', id)
    .single()

  if (!request) {
    notFound()
  }

  const { data: carrierRequests } = await supabase
    .from('carrier_requests')
    .select('*, carriers(*)')
    .eq('transport_request_id', id)
    .order('distance_to_pickup_km', { ascending: true })

  async function handleRunMatching() {
    'use server'
    await runMatching(id)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Request Details</h1>
          <p className="text-gray-500">
            {request.start_country} → {request.destination_country}
          </p>
        </div>
        <div className="flex gap-2">
          {request.status === 'new' && (
            <form action={handleRunMatching}>
              <Button type="submit">Run Matching</Button>
            </form>
          )}
        </div>
      </div>

      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="route">Route & Timing</TabsTrigger>
          <TabsTrigger value="cargo">Cargo</TabsTrigger>
          <TabsTrigger value="offers">Offers ({carrierRequests?.length || 0})</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Request Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-gray-500">Status</p>
                  <Badge>{request.status}</Badge>
                </div>
                <div>
                  <p className="text-sm text-gray-500">Created</p>
                  <p className="font-medium">
                    {new Date(request.created_at).toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-500">Vehicle Type</p>
                  <p className="font-medium">{request.vehicle_type}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-500">Distance</p>
                  <p className="font-medium">{request.distance_km || 'N/A'} km</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {carrierRequests && carrierRequests.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Matching Summary</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold">{carrierRequests.length}</p>
                <p className="text-sm text-gray-500">Carriers matched</p>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="route" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Route Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <h3 className="font-semibold mb-2">Pickup Location</h3>
                <p>{request.start_address}</p>
                <p className="text-sm text-gray-500">
                  {request.start_country} ({request.start_lat}, {request.start_lng})
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-2">Delivery Location</h3>
                <p>{request.destination_address}</p>
                <p className="text-sm text-gray-500">
                  {request.destination_country} ({request.destination_lat}, {request.destination_lng})
                </p>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Timing</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div>
                <p className="text-sm text-gray-500">Pickup Window</p>
                <p className="font-medium">
                  {new Date(request.pickup_date_from).toLocaleString()} -{' '}
                  {new Date(request.pickup_date_to).toLocaleString()}
                </p>
              </div>
              {request.delivery_date_from && (
                <div>
                  <p className="text-sm text-gray-500">Delivery Window</p>
                  <p className="font-medium">
                    {new Date(request.delivery_date_from).toLocaleString()}
                    {request.delivery_date_to && ` - ${new Date(request.delivery_date_to).toLocaleString()}`}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="cargo" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Cargo Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-gray-500">Vehicle Type</p>
                  <p className="font-medium">{request.vehicle_type}</p>
                </div>
                {request.cargo_weight_kg && (
                  <div>
                    <p className="text-sm text-gray-500">Weight</p>
                    <p className="font-medium">{request.cargo_weight_kg} kg</p>
                  </div>
                )}
              </div>

              <div>
                <h3 className="font-semibold mb-2">Special Requirements</h3>
                <div className="flex flex-wrap gap-2">
                  {request.requires_liftgate && <Badge>Liftgate</Badge>}
                  {request.requires_pallet_jack && <Badge>Pallet Jack</Badge>}
                  {request.requires_side_loading && <Badge>Side Loading</Badge>}
                  {request.requires_tarp && <Badge>Tarp</Badge>}
                  {request.requires_gps_tracking && <Badge>GPS Tracking</Badge>}
                  {!request.requires_liftgate &&
                    !request.requires_pallet_jack &&
                    !request.requires_side_loading &&
                    !request.requires_tarp &&
                    !request.requires_gps_tracking && (
                      <p className="text-gray-500">No special requirements</p>
                    )}
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="offers" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Matched Carriers</CardTitle>
            </CardHeader>
            <CardContent>
              {carrierRequests && carrierRequests.length > 0 ? (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Carrier</TableHead>
                      <TableHead>Distance to Pickup</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Offered Price</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {carrierRequests.map((cr: any) => (
                      <TableRow key={cr.id}>
                        <TableCell className="font-medium">
                          {cr.carriers?.company_name}
                        </TableCell>
                        <TableCell>{cr.distance_to_pickup_km} km</TableCell>
                        <TableCell>
                          <Badge>{cr.status}</Badge>
                        </TableCell>
                        <TableCell>
                          {cr.offered_price ? `€${cr.offered_price}` : 'N/A'}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              ) : (
                <div className="text-center py-8">
                  <p className="text-gray-500 mb-4">
                    No carriers matched yet.
                    {request.status === 'new' && ' Run matching to find suitable carriers.'}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}
