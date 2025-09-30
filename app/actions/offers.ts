'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

export async function submitOffer(carrierRequestId: string, data: any) {
  const supabase = await createClient()

  // Check if carrier_request is still valid
  const { data: carrierRequest } = await supabase
    .from('carrier_requests')
    .select('*, transport_requests(*)')
    .eq('id', carrierRequestId)
    .single()

  if (!carrierRequest) {
    return { error: 'Carrier request not found' }
  }

  if (carrierRequest.transport_requests?.status === 'cancelled') {
    return { error: 'This request has been cancelled' }
  }

  // Update carrier_request with offer
  const { error } = await supabase
    .from('carrier_requests')
    .update({
      status: 'offered',
      offered_price: data.offered_price,
      offered_delivery_date: data.offered_delivery_date,
      transport_type: data.transport_type,
      vehicle_type: data.vehicle_type,
      driver_language: data.driver_language,
      notes: data.notes,
      response_date: new Date().toISOString(),
    })
    .eq('id', carrierRequestId)

  if (error) {
    return { error: error.message }
  }

  return { success: true }
}

export async function acceptOffer(carrierRequestId: string) {
  const supabase = await createClient()

  // Get carrier request and transport request
  const { data: carrierRequest } = await supabase
    .from('carrier_requests')
    .select('*, transport_requests(*)')
    .eq('id', carrierRequestId)
    .single()

  if (!carrierRequest) {
    return { error: 'Carrier request not found' }
  }

  // Update this carrier_request to 'won'
  await supabase
    .from('carrier_requests')
    .update({ status: 'won' })
    .eq('id', carrierRequestId)

  // Update all other carrier_requests for this transport_request to 'rejected'
  await supabase
    .from('carrier_requests')
    .update({ status: 'rejected' })
    .eq('transport_request_id', carrierRequest.transport_request_id)
    .neq('id', carrierRequestId)

  // Update transport_request status
  await supabase
    .from('transport_requests')
    .update({
      status: 'matched',
      matched_carrier_id: carrierRequest.carrier_id,
    })
    .eq('id', carrierRequest.transport_request_id)

  revalidatePath(`/requests/${carrierRequest.transport_request_id}`)
  return { success: true }
}

export async function rejectOffer(carrierRequestId: string) {
  const supabase = await createClient()

  const { error } = await supabase
    .from('carrier_requests')
    .update({ status: 'rejected' })
    .eq('id', carrierRequestId)

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/requests')
  return { success: true }
}
