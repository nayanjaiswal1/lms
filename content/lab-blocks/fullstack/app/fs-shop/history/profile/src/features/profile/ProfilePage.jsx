import { useEffect, useState } from 'react';
import { get, put } from '../../lib/api.js';

const CONFLICT_MESSAGE = 'This profile was changed in another tab or device. Reload to see the latest version.';

export default function ProfilePage() {
  const [profile, setProfile] = useState(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [message, setMessage] = useState({ kind: '', text: '' });

  function load(body) {
    setProfile(body);
    setName(body.name);
    setPhone(body.phone);
  }

  useEffect(() => {
    get('/api/profile')
      .then(load)
      .catch(() => setMessage({ kind: 'error', text: 'Could not load your profile.' }));
  }, []);

  async function save(event) {
    event.preventDefault();
    setMessage({ kind: '', text: '' });
    try {
      load(await put('/api/profile', { name, phone, version: profile.version }));
      setMessage({ kind: 'saved', text: 'Profile saved.' });
    } catch (error) {
      const text = error.code === 'version_conflict' ? CONFLICT_MESSAGE : error.message;
      setMessage({ kind: 'error', text });
    }
  }

  if (!profile) return message.text ? <p role="alert">{message.text}</p> : <p>Loading...</p>;
  return (
    <section>
      <h2>Your profile</h2>
      <form onSubmit={save} aria-label="Profile">
        <p>{profile.email}</p>
        <label>
          Name
          <input value={name} onChange={(event) => setName(event.target.value)} required />
        </label>
        <label>
          Phone
          <input value={phone} onChange={(event) => setPhone(event.target.value)} />
        </label>
        <button type="submit">Save</button>
      </form>
      {message.kind === 'error' && <p role="alert">{message.text}</p>}
      {message.kind === 'saved' && <p role="status">{message.text}</p>}
    </section>
  );
}
