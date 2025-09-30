import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'

export default async function RequestsPage() {
  const supabase = await createClient()

  const { data: requests } = await supabase
    .from('transport_requests')
    .select('*')
    .order('created_at', { ascending: false })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Transport Requests</h1>
        <Link href="/requests/new">
          <Button>New Request</Button>
        </Link>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Requests</CardTitle>
        </CardHeader>
        <CardContent>
          {requests && requests.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Route</TableHead>
                  <TableHead>Pickup Date</TableHead>
                  <TableHead>Vehicle Type</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {requests.map((request) => (
                  <TableRow key={request.id}>
                    <TableCell className="font-medium">
                      {request.start_country} → {request.destination_country}
                    </TableCell>
                    <TableCell>
                      {new Date(request.pickup_date_from).toLocaleDateString()}
                    </TableCell>
                    <TableCell>{request.vehicle_type}</TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          request.status === 'new'
                            ? 'default'
                            : request.status === 'matched'
                            ? 'default'
                            : 'secondary'
                        }
                      >
                        {request.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {new Date(request.created_at).toLocaleDateString()}
                    </TableCell>
                    <TableCell>
                      <Link href={`/requests/${request.id}`}>
                        <Button variant="outline" size="sm">
                          View
                        </Button>
                      </Link>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <div className="text-center py-8">
              <p className="text-gray-500 mb-4">
                No requests yet. Create your first transport request.
              </p>
              <Link href="/requests/new">
                <Button>New Request</Button>
              </Link>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
