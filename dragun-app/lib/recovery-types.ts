export const COLLECTION_STATUSES = ['pending', 'contacted', 'promise_to_pay', 'paid', 'no_answer', 'escalated'] as const;
export type CollectionStatus = (typeof COLLECTION_STATUSES)[number];

function toCollectionStatus(input: FormDataEntryValue | null): CollectionStatus {
  const value = String(input ?? 'pending');
  if ((COLLECTION_STATUSES as readonly string[]).includes(value)) {
    return value as CollectionStatus;
  }
  return 'pending';
}

export { toCollectionStatus };
