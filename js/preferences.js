const PREFERENCES = (() => {
  const use = {};
  const cache = {};
  const key = (scope, name) => `${scope}/${name}`;

  function retain(scope, name, value, { force=true }={}) {
    const k = key(scope, name);
    if (force || !(localStorage[k] ?? null)) {
      localStorage[k] = JSON.stringify(value)
    }
    document.documentElement.dataset[name] = localStorage[k];

    // Publish an accessor for static access
    use[k] ?? (use[k] = (on) => {
      cache[k] = retain(scope, name, on);
      document.documentElement.dataset[name] = `${on}`;
      return on;
    });

    return JSON.parse(localStorage[k]);
  }

  function retrieve(scope, name, defaultValue) {
    const k = key(scope, name);
    try {
      return JSON.parse(localStorage[k] ?? JSON.stringify(defaultValue));
    } catch (e) {
      localStorage[k] = JSON.stringify(defaultValue);
      return defaultValue;
    }
  }

  return (scope) => ({
    key,
    retain: (k, v, opts) => retain(scope, k, v, opts),
    retrieve: (k, v, opts) => retrieve(scope, k, v, opts),
    use: name => use[key(scope, name)],
    get: name => cache[key(scope, name)],
  })
})();

// Init and wiring used to live in an inline <script> and an inline onchange= in root.html,
// which is what forced script-src 'unsafe-inline'. They are here now so the policy can refuse
// inline script outright — the layout ships the DEFAULTS as application/json and none of the
// behaviour. Nothing about the preference model changed.
document.addEventListener('DOMContentLoaded', () => {
  const button = document.getElementById("preferences-toggle");
  const form = document.getElementById("preferences");
  if (!button || !form) return;

  button.addEventListener('click', () => {
    const expanded = button.getAttribute('aria-expanded') === 'true';
    button.setAttribute('aria-expanded', String(!expanded));
    form.hidden = expanded;
  });

  const scope = form.dataset.scope;
  const preferences = PREFERENCES(scope);

  // Site defaults, seeded without overwriting a choice the reader already made (force:false).
  let defaults = {};
  try { defaults = JSON.parse(document.getElementById("preference-defaults")?.textContent || "{}"); }
  catch (e) { /* a site that ships no defaults still gets working toggles */ }
  for (const [name, value] of Object.entries(defaults)) {
    preferences.retain(name, value, { force: false });
  }

  for (const input of form.elements) {
    if (input.name) input.checked = preferences.retrieve(input.name, defaults[input.name]);
  }

  // One delegated listener replaces the per-input onchange= the layout used to carry.
  form.addEventListener('change', (e) => {
    const input = e.target;
    if (!input.name) return;
    const setter = preferences.use(input.name);
    if (setter) setter(input.checked);
  });
});
