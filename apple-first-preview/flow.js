(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.PeakWeekOnboarding = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const downloadURL = 'https://apps.apple.com/app/id6797750329';
  const messages = {
    popup_blocked: 'Safari blocked the Apple sign-in window. Open this invitation in Safari and allow the sign-in window, then try again.',
    cancelled: 'Apple sign-in was cancelled. Nothing was connected. You can try again.',
    invitation_unavailable: 'This invitation is no longer available. Ask your coach for a new invitation.',
    other_account: 'This training is linked to a different Apple account. Use the account you connected before, or ask your coach for help.',
    account_deletion_pending: 'Account removal is still finishing. Please wait before starting again.',
    private_test_only: 'This setup test is only available to the invited test account. Your existing invitation still works.',
    unauthorized: 'Apple sign-in could not be verified. Please try again.',
    unavailable: 'This setup option is not available yet. Your existing invitation still works.',
    network: 'We could not finish connecting. Check your connection and try again. A retry will not create another profile.',
    invalid_reply: 'The connection was not confirmed. Please try again.',
  };
  function invitation(fragment) {
    const p = new URLSearchParams(String(fragment).replace(/^#/, ''));
    if (p.getAll('invite').length !== 1 || p.has('code') || p.getAll('api').length > 1 || (p.has('api') && p.get('api') !== '2')) return null;
    const value = p.get('invite').toUpperCase();
    return /^[A-F0-9]{64}$/.test(value) ? value : null;
  }
  function validReceipt(result) {
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return result?.ok === true && uuid.test(result.workspace_id) && uuid.test(result.client_id);
  }
  function createFlow({ fragment, adapter, onChange = () => {} }) {
    let credential = invitation(fragment), generation = 0;
    let state = { phase: !credential ? 'invalid' : adapter ? 'welcome' : 'unconfigured' };
    function update(next) { state = Object.freeze(next); onChange(state); return state; }
    const api = {
      get state() { return state; },
      async continueWithApple() {
        if (!credential || !adapter || state.phase === 'connecting' || state.phase === 'connected') return state;
        const current = ++generation, pending = credential;
        update({ phase: 'connecting' });
        try {
          const receipt = await adapter.claim(pending);
          if (generation !== current) return state;
          if (!validReceipt(receipt)) throw { code: 'invalid_reply' };
          // Retain no invitation or account identifiers in the presentation state.
          credential = null;
          return update({ phase: 'connected', downloadURL });
        } catch (error) {
          if (generation !== current) return state;
          const code = Object.hasOwn(messages, error?.code) ? error.code : 'network';
          return update({ phase: 'error', code, message: messages[code] });
        }
      },
      reset(fragment) {
        generation++; credential = invitation(fragment);
        return update({ phase: !credential ? 'invalid' : adapter ? 'welcome' : 'unconfigured' });
      },
      start() { return update(state); },
    };
    return api;
  }
  // authenticate must be supplied by a verified Apple web integration. This
  // module neither invents authentication nor persists provider credentials.
  function createClaimAdapter({ authenticate, fetcher, apiBase }) {
    const base = new URL(apiBase);
    if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash) throw Error('HTTPS API origin required');
    if (typeof authenticate !== 'function' || typeof fetcher !== 'function') throw Error('Verified authentication adapter required');
    return {
      async claim(invite) {
        const session = await authenticate();
        if (!session || typeof session.accessToken !== 'string' || !session.accessToken) throw { code: 'unauthorized' };
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 30000);
        try {
          const response = await fetcher(base.href.replace(/\/$/, '') + '/lifter-account/claim-invitation', {
            method: 'POST', credentials: 'omit', redirect: 'error', cache: 'no-store', referrerPolicy: 'no-referrer', signal: controller.signal,
            headers: { 'Authorization': 'Bearer ' + session.accessToken, 'Content-Type': 'application/json' },
            body: JSON.stringify({ invitation: invite }),
          });
          const body = await response.json().catch(() => ({}));
          if (response.status === 401) throw { code: 'unauthorized' };
          if (response.status === 404) throw { code: 'unavailable' };
          if (!response.ok) throw { code: Object.hasOwn(messages, body.code) ? body.code : 'network' };
          return body;
        } finally { clearTimeout(timeout); }
      },
    };
  }
  return { createFlow, createClaimAdapter, invitation, downloadURL };
});
