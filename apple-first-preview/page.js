'use strict';
const $ = id => document.getElementById(id);
let flow, generation = 0, initialization = 0, adapterPromise;
function render(state) {
  const connected = state.phase === 'connected';
  $('welcome').hidden = connected; $('ready').hidden = !connected;
  $('apple').disabled = !['welcome', 'error'].includes(state.phase);
  $('apple').textContent = state.phase === 'connecting' ? 'Connecting…' : 'Continue with Apple';
  $('status').textContent = state.message || ({unconfigured:'Apple setup is not connected in this private preview.',invalid:'Open a complete invitation from your coach. You can also explore the fictional preview below.',connecting:'Saving your connection…'}[state.phase] || '');
}
function mount(adapter, fragment) {
  const current = ++generation;
  flow?.reset(''); // An old in-flight response must not replace the new screen.
  flow = PeakWeekOnboarding.createFlow({fragment,adapter,onChange:state => {
    if (generation === current) render(state);
  }});
  flow.start();
}
// Disabled by default. Publishing a separate private configuration requires
// verified Apple Services ID/grouping, a matching backend gate, and approval.
mount(null, location.hash);
async function enableConfiguredApple() {
  const config = window.PeakWeekPrivateAppleConfig;
  if (!config?.enabled) return;
  $('fictional-demo').hidden = true;
  const current = ++initialization;
  try {
    if (!adapterPromise) adapterPromise = (async () => {
      PeakWeekAppleAuth.validateConfig(config, location.origin);
      await new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
        script.referrerPolicy = 'no-referrer'; script.onload = resolve; script.onerror = reject;
        document.head.appendChild(script);
      });
      const authenticate = await PeakWeekAppleAuth.createAuthenticator({config,origin:location.origin,apple:window.AppleID,fetcher:window.fetch.bind(window)});
      return PeakWeekOnboarding.createClaimAdapter({authenticate,fetcher:window.fetch.bind(window),apiBase:config.supabaseOrigin+'/functions/v1/peakweek-native-api'});
    })();
    const adapter = await adapterPromise;
    if (current === initialization) mount(adapter,location.hash);
  } catch (_) {
    if (current !== initialization) return;
    adapterPromise = undefined;
    $('status').textContent = 'Apple setup could not start. Please open this invitation in Safari and try again. Nothing has been connected.';
  }
}
enableConfiguredApple();
$('apple').addEventListener('click', () => flow.continueWithApple());
window.addEventListener('hashchange', () => { mount(null,location.hash); enableConfiguredApple(); });
$('simulate').addEventListener('click', () => {
  if (window.PeakWeekPrivateAppleConfig?.enabled) return;
  $('preview-label').textContent = 'FICTIONAL PREVIEW — NO ACCOUNT CONNECTED';
  const outcome = $('scenario').value;
  mount({async claim() {
    if (outcome !== 'success') throw {code:outcome};
    return {ok:true,workspace_id:'00000000-0000-4000-8000-000000000001',client_id:'00000000-0000-4000-8000-000000000002'};
  }}, '#invite='+'AB'.repeat(32)+'&api=2');
  $('status').textContent = 'Fictional preview only. Continue to preview the selected outcome.';
});
