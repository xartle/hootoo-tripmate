/* Injected into the stock TripMate UI when TRIPPY_SKIN=1.
   Proof-of-takeover banner that links to our control panel. */
(function(){
  try{
    var port=8080, host=location.hostname;
    var d=document.createElement('div');
    d.style.cssText='position:fixed;top:0;left:0;right:0;z-index:99999;'+
      'background:#0d1117;color:#7ee787;font:13px/1.4 monospace;'+
      'padding:6px 10px;border-bottom:2px solid #2ea043;text-align:center';
    d.innerHTML='⚡ trippy: stock UI overlaid from USB extern_package &nbsp;|&nbsp; '+
      '<a style="color:#58a6ff" href="http://'+host+':'+port+'/">open control panel</a>';
    document.body.insertBefore(d, document.body.firstChild);
    document.body.style.marginTop='34px';
  }catch(e){}
})();
