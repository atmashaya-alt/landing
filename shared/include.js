/* Tiny fetch-based include loader for the zero-build landing site.
   Place <script src="shared/include.js"> at the END of <body>, after
   every <div data-include="name"></div> placeholder, so this runs the
   instant the browser reaches it (no need to wait for DOMContentLoaded —
   everything above it in the document has already been parsed).

   Real gotcha this exists to handle: setting .innerHTML with a string
   containing <script> tags does NOT execute those scripts. Each fetched
   partial's script tag is explicitly cloned into a fresh <script>
   element and re-appended so it actually runs. */
(function(){
  var placeholders = document.querySelectorAll('[data-include]');
  placeholders.forEach(function(el){
    var name = el.getAttribute('data-include');
    fetch('shared/' + name + '.html', { cache: 'no-cache' })
      .then(function(res){ return res.text(); })
      .then(function(html){
        el.innerHTML = html;
        el.querySelectorAll('script').forEach(function(oldScript){
          var newScript = document.createElement('script');
          if (oldScript.src) newScript.src = oldScript.src;
          newScript.textContent = oldScript.textContent;
          oldScript.parentNode.replaceChild(newScript, oldScript);
        });
      })
      .catch(function(err){ console.error('Failed to load partial "' + name + '":', err); });
  });
})();
