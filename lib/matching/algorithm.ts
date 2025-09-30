import { createClient } from '@/lib/supabase/server'
import { calculateDistance } from './distance'

export async function matchCarriersToRequest(requestId: string) {
  const supabase = await createClient()

  // Fetch request details
  const { data: request, error: requestError } = await supabase
    .from('transport_requests')
    .select('*')
    .eq('id', requestId)
    .single()

  if (requestError || !request) {
    throw new Error('Request not found')
  }

  // Fetch all non-blacklisted carriers
  const { data: carriers, error: carriersError } = await supabase
    .from('carriers')
    .select('*')
    .eq('blacklisted', false)

  if (carriersError || !carriers) {
    throw new Error('Failed to fetch carriers')
  }

  const matchedCarriers: any[] = []

  for (const carrier of carriers) {
    let isMatch = true
    let distance_to_pickup = 0
    let in_radius = false

    // Filter 1: Check vehicle availability
    if (request.vehicle_type === 'transporter' && !carrier.has_transporter) {
      continue
    }
    if (['lkw_749', 'lkw_1199', 'lkw_bdf', 'sattelzug', 'niederzug'].includes(request.vehicle_type) && !carrier.has_lkw) {
      continue
    }

    // Filter 2: Geographic coverage
    const pickupCountries = carrier.pickup_countries || []
    const deliveryCountries = carrier.delivery_countries || []

    if (pickupCountries.length > 0 && !pickupCountries.includes(request.start_country)) {
      continue
    }
    if (deliveryCountries.length > 0 && !deliveryCountries.includes(request.destination_country)) {
      continue
    }

    // Filter 3: Radius check
    distance_to_pickup = calculateDistance(
      carrier.lat,
      carrier.lng,
      request.start_lat,
      request.start_lng
    )

    if (!carrier.ignore_radius) {
      if (distance_to_pickup > (carrier.pickup_radius_km || 50)) {
        continue
      }
      in_radius = true
    }

    // Filter 4: Vehicle capacity (if LKW required)
    if (carrier.has_lkw && request.cargo_length_cm && request.cargo_width_cm && request.cargo_height_cm) {
      if (
        carrier.lkw_length_cm &&
        carrier.lkw_width_cm &&
        carrier.lkw_height_cm &&
        (carrier.lkw_length_cm < request.cargo_length_cm ||
          carrier.lkw_width_cm < request.cargo_width_cm ||
          carrier.lkw_height_cm < request.cargo_height_cm)
      ) {
        continue
      }
    }

    // Filter 5: Special equipment
    if (request.requires_liftgate && !carrier.has_liftgate) {
      continue
    }
    if (request.requires_pallet_jack && !carrier.has_pallet_jack) {
      continue
    }

    // Calculate distance to delivery
    const distance_to_delivery = calculateDistance(
      carrier.lat,
      carrier.lng,
      request.destination_lat,
      request.destination_lng
    )

    matchedCarriers.push({
      carrier_id: carrier.id,
      distance_to_pickup_km: distance_to_pickup,
      distance_to_delivery_km: distance_to_delivery,
      in_radius,
    })
  }

  // Create carrier_request records
  for (const match of matchedCarriers) {
    await supabase.from('carrier_requests').insert({
      transport_request_id: requestId,
      carrier_id: match.carrier_id,
      distance_to_pickup_km: match.distance_to_pickup_km,
      distance_to_delivery_km: match.distance_to_delivery_km,
      in_radius: match.in_radius,
      status: 'new',
    })
  }

  // Update request status
  await supabase
    .from('transport_requests')
    .update({
      matchmaking_status: 'completed',
      status: matchedCarriers.length > 0 ? 'matched' : 'matching',
    })
    .eq('id', requestId)

  return { count: matchedCarriers.length }
}
