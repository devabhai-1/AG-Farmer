(function () {
  var fallback = [
    { name: 'मुफ़्त / Free', price: '₹0', note: 'सीमित चैट · मौसम' },
    { name: 'लहसुन स्पेशल', price: '₹299', note: 'अफीम छोड़कर सभी कोर्स · /माह' },
    { name: 'अफीम स्पेशल', price: '₹599', note: 'अफीम सहित सभी फसलें · /माह' },
    { name: 'सुपर प्रीमियम', price: '₹2650', note: 'वीडियो + AG Live · /माह' },
    { name: 'डिस्ट्रीब्यूटर प्रो', price: '₹13500', note: 'सुपर से 10 गुना सीमा · /माह' },
  ];
  var ids = ['free', 'advanced', 'all', 'super', 'distributor'];

  var style = document.createElement('style');
  style.textContent =
    '.ag-plans{margin:2rem 0;padding:1.25rem;border:1px solid #bae6fd;border-radius:16px;background:#f0f9ff}' +
    '.ag-plans h2{margin:0 0 .75rem;font-size:1.25rem;color:#032b43}' +
    '.ag-plans-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.75rem}' +
    '.ag-plan{background:#fff;border:1px solid #bae6fd;border-radius:12px;padding:.75rem}' +
    '.ag-plan strong{display:block;color:#032b43}' +
    '.ag-plan b{color:#0284c7;font-size:1.15rem}' +
    '.ag-plan s{color:#64748b;margin-left:.35rem}' +
    '.ag-plan span{display:block;color:#475569;font-size:.85rem;margin-top:.25rem}';
  document.head.appendChild(style);

  function paint(plans) {
    var old = document.querySelector('.ag-plans');
    if (old) old.remove();
    var box = document.createElement('section');
    box.className = 'ag-plans';
    box.innerHTML =
      '<h2>AG Farmer प्लान</h2><div class="ag-plans-grid">' +
      plans
        .map(function (p) {
          return (
            '<article class="ag-plan"><strong>' +
            p.name +
            '</strong><b>' +
            p.price +
            '</b>' +
            (p.mrp ? '<s>' + p.mrp + '</s>' : '') +
            '<span>' +
            p.note +
            '</span></article>'
          );
        })
        .join('') +
      '</div>';
    var footer = document.querySelector('footer');
    if (footer && footer.parentNode) footer.parentNode.insertBefore(box, footer);
    else document.body.appendChild(box);
  }

  paint(fallback);

  fetch('https://api.ag-farmer.com/api', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'catalog.plans' }),
  })
    .then(function (r) {
      return r.json();
    })
    .then(function (body) {
      if (!body || !body.plans) return;
      paint(
        fallback.map(function (p, i) {
          var row = body.plans[ids[i]];
          if (!row) return p;
          var mrp = Math.round(Number(row.priceInr) || 0);
          var sale = Math.round(Number(row.saleInr) || 0);
          var pay = sale > 0 && sale < mrp ? sale : mrp;
          return {
            name: p.name,
            price: '₹' + pay,
            mrp: sale > 0 && sale < mrp ? '₹' + mrp : '',
            note: p.note,
          };
        }),
      );
    })
    .catch(function () {});
})();
