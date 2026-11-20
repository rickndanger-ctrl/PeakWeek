(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.PeakWeekPublicSetup=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
function mode(config, page, fragment, preview=false){
 if(config?.enabled!==true)return 'legacy';
 if(page==='callback'||page==='manage')return 'apple';
 if(config.releaseReady!==true&&!preview)return 'legacy';
 const p=new URLSearchParams(String(fragment).replace(/^#/,''));
 const invites=p.getAll('invite'),versions=p.getAll('api');
 if(invites.length!==1||p.has('code')||versions.length>1||(versions.length&&versions[0]!=='2')||!/^[A-Fa-f0-9]{64}$/.test(invites[0]))return 'legacy';
 return 'apple';
}
return {mode};
});
if(typeof document!=='undefined'){
 const data=document.body.dataset;
 const selected=PeakWeekPublicSetup.mode(window.PeakWeekAppleConfig,data.callback==='true'?'callback':data.operation==='manage'?'manage':'invitation',location.hash,data.setupPreview==='true');
 window.PeakWeekUseAppleSetup=selected==='apple';
 document.getElementById('apple-onboarding').hidden=selected!=='apple';
 document.getElementById('legacy-onboarding').hidden=selected!=='legacy';
 if(selected==='legacy')window.PeakWeekLegacy.render();
 else{
  const fallback=document.getElementById('legacy-connect');
  if(fallback){const url=window.PeakWeekLegacy.invitation(location.hash);if(url)fallback.href=url;else document.getElementById('legacy-fallback').hidden=true;}
 }
 window.addEventListener('hashchange',()=>location.reload());
}
