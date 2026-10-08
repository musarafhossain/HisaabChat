import type { PersonEntry } from '#services/people_service'

/** PersonDTO: the person plus where you stand with them. */
export function personDto(entry: PersonEntry) {
  const { person } = entry
  return {
    id: person.id,
    name: person.name,
    phone: person.phone,
    note: person.note,
    color: person.color,
    archived: person.archived,
    /** Positive = they owe you; negative = you owe them. */
    balance: entry.balance,
    lastActivity: entry.lastActivity,
  }
}
