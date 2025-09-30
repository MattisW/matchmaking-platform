import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export default function MatchesPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Active Matches</h1>
      <Card>
        <CardHeader>
          <CardTitle>Coming Soon</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-gray-500">
            View all active carrier-request matches here.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
