'use server'

import { createClient } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

export async function createCarrier(data: any) {
  const supabase = await createClient()

  const { error } = await supabase.from('carriers').insert([data])

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/carriers')
  return { success: true }
}

export async function updateCarrier(id: string, data: any) {
  const supabase = await createClient()

  const { error } = await supabase
    .from('carriers')
    .update(data)
    .eq('id', id)

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/carriers')
  revalidatePath(`/carriers/${id}`)
  return { success: true }
}

export async function deleteCarrier(id: string) {
  const supabase = await createClient()

  const { error } = await supabase
    .from('carriers')
    .delete()
    .eq('id', id)

  if (error) {
    return { error: error.message }
  }

  revalidatePath('/carriers')
  return { success: true }
}
