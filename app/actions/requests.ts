'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

export async function createRequest(data: any) {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  // Convert empty strings to null for timestamp and numeric fields
  const sanitizedData = {
    ...data,
    delivery_date_from: data.delivery_date_from || null,
    delivery_date_to: data.delivery_date_to || null,
    pickup_date_from: data.pickup_date_from || null,
    pickup_date_to: data.pickup_date_to || null,
    distance_km: data.distance_km || null,
    cargo_length_cm: data.cargo_length_cm || null,
    cargo_width_cm: data.cargo_width_cm || null,
    cargo_height_cm: data.cargo_height_cm || null,
    cargo_weight_kg: data.cargo_weight_kg || null,
    loading_meters: data.loading_meters || null,
    customer_id: user?.id,
  }

  const { error } = await supabase.from('transport_requests').insert([sanitizedData])

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/requests')
  return { success: true }
}

export async function updateRequest(id: string, data: any) {
  const supabase = await createClient()

  const { error } = await supabase
    .from('transport_requests')
    .update(data)
    .eq('id', id)

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/requests')
  revalidatePath(`/requests/${id}`)
  return { success: true }
}

export async function cancelRequest(id: string) {
  const supabase = await createClient()

  const { error } = await supabase
    .from('transport_requests')
    .update({ status: 'cancelled' })
    .eq('id', id)

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/requests')
  revalidatePath(`/requests/${id}`)
  return { success: true }
}
