'use server'

import { matchCarriersToRequest } from '@/lib/matching/algorithm'
import { revalidatePath } from 'next/cache'

export async function runMatching(requestId: string) {
  try {
    const result = await matchCarriersToRequest(requestId)
    revalidatePath(`/requests/${requestId}`)
    return { success: true, count: result.count }
  } catch (error: any) {
    return { error: error.message }
  }
}
