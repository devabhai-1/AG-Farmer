export function Field({ label, value, onChange, type = 'number', min = '0' }) {
  return (
    <label>
      {label}
      <input type={type} value={value ?? ''} min={min} onChange={(e) => onChange(e.target.value)} />
    </label>
  );
}

export function Check({ label, checked, onChange, disabled = false }) {
  return (
    <label className="check">
      <input type="checkbox" checked={!!checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      {label}
    </label>
  );
}

export function Banner({ note, error }) {
  return (
    <>
      {note ? <span className="msg">{note}</span> : null}
      {error ? <span className="err">{error}</span> : null}
    </>
  );
}
