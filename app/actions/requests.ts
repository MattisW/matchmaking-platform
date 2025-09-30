'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

export async function createRequest(data: any) {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  const { error } = await supabase.from('transport_requests').insert([{
    ...data,
    customer_id: user?.id,
  }])

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
