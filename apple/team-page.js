// Team link (#team=CODE): the coach posts one link for the whole team. This
// page never sends anything; it helps the lifter get the app and open it with
// the code. Joining, Apple sign-in and the coach's approval happen in the app.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.PeakWeekTeam=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const ALPHABET=/^[A-HJ-NP-Z2-9]{8}$/;
function code(fragment){
 const p=new URLSearchParams(String(fragment||'').replace(/^#/,''));
 const values=p.getAll('team');
 if(values.length!==1||p.has('invite')||p.has('code'))return null;
 const value=values[0].toUpperCase().replace(/[^A-Z0-9]/g,'');
 return ALPHABET.test(value)?value:null;
}
function display(value){return value.slice(0,4)+'-'+value.slice(4);}
function appURL(value){return 'peakweek://join?team='+encodeURIComponent(value);}
return {code,display,appURL};
});
if(typeof document!=='undefined'){
 const team=PeakWeekTeam.code(location.hash);
 window.PeakWeekTeamPage=!!team;
 if(team){
  window.PeakWeekUseAppleSetup=false;
  document.getElementById('team-onboarding').hidden=false;
  document.getElementById('apple-onboarding').hidden=true;
  document.getElementById('legacy-onboarding').hidden=true;
  document.getElementById('team-code').textContent=PeakWeekTeam.display(team);
  document.getElementById('team-open').href=PeakWeekTeam.appURL(team);
 }
}
