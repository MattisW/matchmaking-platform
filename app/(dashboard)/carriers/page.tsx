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

export default async function CarriersPage() {
  const supabase = await createClient()

  const { data: carriers } = await supabase
    .from('carriers')
    .select('*')
    .order('created_at', { ascending: false })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Carriers</h1>
        <Link href="/carriers/new">
          <Button>Add Carrier</Button>
        </Link>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Carriers</CardTitle>
        </CardHeader>
        <CardContent>
          {carriers && carriers.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Company</TableHead>
                  <TableHead>Country</TableHead>
                  <TableHead>Contact</TableHead>
                  <TableHead>Vehicle Types</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {carriers.map((carrier) => (
                  <TableRow key={carrier.id}>
                    <TableCell className="font-medium">
                      {carrier.company_name}
                    </TableCell>
                    <TableCell>{carrier.country}</TableCell>
                    <TableCell>{carrier.contact_email}</TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {carrier.has_transporter && (
                          <Badge variant="secondary">Transporter</Badge>
                        )}
                        {carrier.has_lkw && (
                          <Badge variant="secondary">LKW</Badge>
                        )}
                      </div>
                    </TableCell>
                    <TableCell>
                      {carrier.blacklisted ? (
                        <Badge variant="destructive">Blacklisted</Badge>
                      ) : (
                        <Badge variant="default">Active</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      <Link href={`/carriers/${carrier.id}`}>
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
                No carriers yet. Add your first carrier to get started.
              </p>
              <Link href="/carriers/new">
                <Button>Add Carrier</Button>
              </Link>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
