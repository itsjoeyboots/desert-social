// Validates each form in the browser, posts it to the database function, and shows
// what really happened: sending, received, or failed with a way to reach us.
// The server validates everything again; this is only for fast feedback.

type Control = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const loadedAt = Date.now();

function messageFor(el: Control): string {
  const value = el.value.trim();
  if (el.required && !value) {
    return el.tagName === 'SELECT' ? 'Choose an option.' : 'This one is required.';
  }
  if (!value) return '';
  if (el.type === 'email' && !EMAIL.test(value)) return 'That email address doesn’t look right.';
  if (el.type === 'tel' && value.replace(/\D/g, '').length < 7) return 'Add a full phone number.';
  if (el.name === 'reason' && value.length < 20) return 'Tell us a little more: a sentence or two is plenty.';
  if (el.name === 'message' && value.length < 10) return 'Add a few more words so we can help.';
  return '';
}

function showError(el: Control, message: string) {
  const error = el.closest('[data-field]')?.querySelector<HTMLElement>('[data-error]');
  if (message) el.setAttribute('aria-invalid', 'true');
  else el.removeAttribute('aria-invalid');
  if (error) {
    error.textContent = message;
    error.hidden = !message;
  }
}

function validateGroup(group: HTMLFieldSetElement): boolean {
  const ok = group.querySelectorAll('input:checked').length > 0;
  const error = group.querySelector<HTMLElement>('[data-error]');
  if (error) {
    error.textContent = ok ? '' : 'Pick at least one.';
    error.hidden = ok;
  }
  return ok;
}

function setStatus(form: HTMLFormElement, html: string) {
  const status = form.querySelector<HTMLElement>('[data-status]');
  if (!status) return;
  status.innerHTML = html;
  status.hidden = !html;
}

function setBusy(form: HTMLFormElement, busy: boolean) {
  const button = form.querySelector<HTMLButtonElement>('[data-submit]');
  if (!button) return;
  button.disabled = busy;
  button.setAttribute('aria-busy', String(busy));
  button.textContent = busy ? 'Sending…' : button.dataset.label || 'Send';
}

function collect(form: HTMLFormElement): Record<string, string | string[]> {
  const data: Record<string, string | string[]> = {};
  const fd = new FormData(form);
  for (const key of new Set(fd.keys())) {
    if (key === 'nickname') continue;
    const all = fd.getAll(key).map((v) => String(v).trim());
    data[key] = form.querySelector(`[name="${key}"][type="checkbox"]`) ? all : all[0];
  }
  return data;
}

function init(form: HTMLFormElement) {
  const controls = Array.from(form.querySelectorAll<Control>('[data-field] input, [data-field] select, [data-field] textarea'));
  const groups = Array.from(form.querySelectorAll<HTMLFieldSetElement>('fieldset[data-required-group]'));
  const email = form.dataset.email || '';
  const mailLink = `<a href="mailto:${email}">${email}</a>`;
  let tried = false;

  controls.forEach((el) => {
    el.addEventListener('blur', () => {
      if (tried || el.value.trim()) showError(el, messageFor(el));
    });
    el.addEventListener('input', () => {
      if (el.getAttribute('aria-invalid') === 'true') showError(el, messageFor(el));
    });
  });
  groups.forEach((g) => g.addEventListener('change', () => tried && validateGroup(g)));

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    tried = true;
    setStatus(form, '');

    let firstBad: HTMLElement | null = null;
    for (const el of controls) {
      const message = messageFor(el);
      showError(el, message);
      if (message && !firstBad) firstBad = el;
    }
    for (const g of groups) {
      if (!validateGroup(g) && !firstBad) firstBad = g.querySelector('input');
    }
    if (firstBad) {
      firstBad.focus();
      return;
    }

    const endpoint = form.dataset.endpoint;
    const key = form.dataset.key || '';
    if (!endpoint) {
      setStatus(form, `This form isn’t connected yet. Email ${mailLink} and we’ll take it from there.`);
      return;
    }

    setBusy(form, true);
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 20000);

    try {
      // supabase/setup.sql → public.submit_form(). It always answers 200 with
      // { ok } or { ok: false, error, fields }; anything else is a failure.
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: key },
        signal: controller.signal,
        body: JSON.stringify({
          form_name: form.dataset.form,
          payload: collect(form),
          nickname: (form.elements.namedItem('nickname') as HTMLInputElement | null)?.value || '',
          elapsed_ms: Date.now() - loadedAt,
          page: location.pathname,
        }),
      });
      const result = await response.json().catch(() => ({}));

      if (response.ok && result.ok === true) {
        const shell = form.closest('[data-form-shell]');
        const done = shell?.querySelector<HTMLElement>('[data-done]');
        form.hidden = true;
        if (done) {
          done.hidden = false;
          done.focus();
          done.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
        return;
      }

      if (result.error === 'invalid' && result.fields) {
        let first: Control | null = null;
        for (const [name, message] of Object.entries(result.fields as Record<string, string>)) {
          const el = controls.find((c) => c.name === name);
          if (el) {
            showError(el, message);
            first ??= el;
          }
        }
        setStatus(form, 'A few details need another look.');
        first?.focus();
      } else if (result.error === 'rate_limited') {
        setStatus(form, `That’s a lot of attempts in a short time. Try again in a few minutes, or email ${mailLink}.`);
      } else {
        setStatus(form, `That didn’t go through, and it’s on our side. Try once more, or email ${mailLink}.`);
      }
    } catch {
      setStatus(form, `We couldn’t reach the server. Check your connection and try again, or email ${mailLink}.`);
    } finally {
      window.clearTimeout(timer);
      setBusy(form, false);
    }
  });
}

document.querySelectorAll<HTMLFormElement>('form[data-form]').forEach((form) => {
  if (form.dataset.ready) return;
  form.dataset.ready = 'true';
  init(form);
});
