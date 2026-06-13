(function(){if(window.__coloInfoInjected)return;window.__coloInfoInjected=true;
var coloMap={HKG:'Hong Kong',NRT:'Tokyo, JP',KIX:'Osaka, JP',ICN:'Seoul, KR',SIN:'Singapore',SJC:'San Jose, US',SFO:'San Francisco, US',LAX:'Los Angeles, US',SEA:'Seattle, US',FRA:'Frankfurt, DE',LHR:'London, GB',AMS:'Amsterdam, NL',CDG:'Paris, FR',MAD:'Madrid, ES',SYD:'Sydney, AU',MEL:'Melbourne, AU'};
function injectColoWidget(){
  var aside=document.getElementById('aside-content');
  if(!aside||document.getElementById('colo-info'))return;
  var cardArchives=aside.querySelector('.card-archives');
  if(!cardArchives)return;
  var widget=document.createElement('div');
  widget.className='card-widget colo-info';
  widget.id='colo-info';
  widget.innerHTML='<div class="item-headline"><i class="fas fa-satellite-dish fa-flip"></i><span>Cloudflare 节点信息</span></div><div class="item-content"><div class="webinfo"><div class="webinfo-item"><div class="item-name">访问 IP :</div><div class="item-count" id="cf-ip">加载中...</div></div><div class="webinfo-item"><div class="item-name">访问地区 :</div><div class="item-count" id="cf-loc">加载中...</div></div><div class="webinfo-item"><div class="item-name">CDN 节点 :</div><div class="item-count" id="cf-colo">加载中...</div></div><div class="webinfo-item"><div class="item-name">TLS 协议 :</div><div class="item-count" id="cf-tls">加载中...</div></div><div class="webinfo-item"><div class="item-name">WARP :</div><div class="item-count" id="cf-warp">加载中...</div></div></div></div>';
  cardArchives.insertAdjacentElement('afterend',widget);
  fetchColoData();
}
function fetchColoData(){
  function s(id,text){
    var el=document.getElementById(id);
    if(!el)return;
    el.textContent=text||'未知';
    if(id==='cf-ip'){
      var ipItem=el.closest('.webinfo-item');
      if(ipItem){
        if((text||'未知').length>15)ipItem.classList.add('ip-wrap');
        else ipItem.classList.remove('ip-wrap');
      }
    }
  }
  fetch('/cdn-cgi/trace',{cache:'no-store'})
  .then(function(r){return r.text()})
  .then(function(t){
    var data={},lines=t.split('\n');
    for(var i=0;i<lines.length;i++){
      var line=lines[i].trim();
      if(!line)continue;
      var p=line.split('=');
      if(p.length<2)continue;
      data[p[0].trim()]=p.slice(1).join('=').trim();
    }
    s('cf-ip',data.ip);
    s('cf-loc',data.loc);
    var colo=data.colo;
    var coloText;
    if(colo){
      var city=coloMap[colo];
      coloText=city?colo+' ('+city+')':colo;
    }else{coloText='未知';}
    s('cf-colo',coloText);
    s('cf-tls',data.tls);
    var w=data.warp;
    s('cf-warp',w==='on'?'启用':w==='off'?'关闭':w||'未知');
  })
  .catch(function(){
    s('cf-ip','加载失败');
    s('cf-loc','加载失败');
    s('cf-colo','加载失败');
    s('cf-tls','加载失败');
    s('cf-warp','加载失败');
  });
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',injectColoWidget);
else injectColoWidget();
document.addEventListener('pjax:complete',function(){window.__coloInfoInjected=false;injectColoWidget()});
})();