import { useState } from 'react';

/** One note. Edits stay a local draft until Save. */
export default function NoteRow({ note, onSave, onDelete }) {
  const [draft, setDraft] = useState(note.text);
  const dirty = draft !== note.text;

  return (
    <li>
      <input aria-label="Note text" value={draft} onChange={(event) => setDraft(event.target.value)} />
      {dirty && (
        <button type="button" onClick={() => onSave(note.id, draft)}>
          Save
        </button>
      )}
      <button type="button" aria-label="Delete note" onClick={() => onDelete(note.id)}>
        Delete
      </button>
    </li>
  );
}
