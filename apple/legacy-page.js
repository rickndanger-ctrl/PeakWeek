
// This page never redeems an invitation. Only the native app can connect.
// Keep the download free of invitation data: the App Store does not preserve it.
function invitationFromFragment(fragment) {
 const params = new URLSearchParams(fragment.replace(/^#/, ''));
 const invites = params.getAll('invite'), codes = params.getAll('code'), versions = params.getAll('api');
 if (invites.length + codes.length !== 1 || versions.length > 1 ||
     (versions.length && !['1','2'].includes(versions[0]))) return null;
 const value = (invites[0] || codes[0] || '').toUpperCase();
 const legacy = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$/.test(value);
 if (!legacy && !/^[A-F\d]{64}$/.test(value)) return null;
 const api = legacy ? 1 : Number(versions[0] || 2);
 return `peakweek://pair?${legacy ? 'code' : 'invite'}=${encodeURIComponent(value)}&api=${api}`;
}
function renderInvitation() {
const appURL = invitationFromFragment(location.hash);
const download = document.querySelector('#download');
download.href = 'https://apps.apple.com/app/id6797750329';
download.rel = 'noreferrer';
document.querySelector('#installStep').hidden = false;
document.querySelector('#connectStep').hidden = !appURL;
document.querySelector('#releaseNotice').hidden = !appURL;
document.querySelector('#connect').removeAttribute('href');
document.querySelector('#connectStatus').textContent = '';
download.onclick = () => {
 document.querySelector('#releaseNotice').hidden = false;
 document.querySelector('#releaseNotice').textContent = appURL
  ? 'After installing: return to this page and tap Connect to your coach below. Your program opens in Peak Week Lifter.'
  : 'After installing, open the personal invitation your coach sent you.';
};
document.querySelector('#connect').onclick = () => {
 document.querySelector('#connectStatus').textContent = 'Opening Peak Week Lifter… If it stays on this page, use the help below. If the app asks to connect this invitation, confirm there.';
};
if (appURL) {
 document.querySelector('#description').textContent = 'Your coach’s invitation connects the app to your training.';
 document.querySelector('#connect').href = appURL;
 document.querySelector('#connectStep').hidden = false;
} else {
 document.querySelector('#description').textContent = 'Download Peak Week Lifter below. To see your own training, open the complete personal invitation from your coach. If this invitation is incomplete, ask your coach for a new one.';
 document.querySelector('#releaseNotice').hidden = true;
}
}
window.PeakWeekLegacy={render:renderInvitation,invitation:invitationFromFragment};
