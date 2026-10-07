import { useState } from 'react';
import NoteRow from './NoteRow.jsx';
import { useNotes } from './useNotes.js';

export default function NotesPanel({ orderId }) {
  const { notes, loading, error, add, save, remove } = useNotes(orderId);
  const [text, setText] = useState('');

  async function submit(event) {
    event.preventDefault();
    if (text.trim() === '') return;
    await add(text);
    setText('');
  }

  // mf:slot notes.panel.rows
  const rows = notes.map((note) => <NoteRow key={note.id} note={note} onSave={save} onDelete={remove} />);
  // mf:endslot

  return (
    <div aria-busy={loading}>
      {error && <p role="alert">Could not load the notes.</p>}
      {!loading && !error && notes.length === 0 && <p>No notes yet.</p>}
      <ul aria-label={`Notes for order ${orderId}`}>{rows}</ul>
      <form aria-label="Add note" onSubmit={submit}>
        <input aria-label="New note" value={text} onChange={(event) => setText(event.target.value)} />
        <button type="submit">Add note</button>
      </form>
    </div>
  );
}
