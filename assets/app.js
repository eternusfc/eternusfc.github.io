const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const POSICOES = ['Goleiro', 'Fixo', 'Ala', 'Pivô', 'Técnico'];
const PES = ['Direito', 'Esquerdo', 'Ambidestro'];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmtAltura = cm => (cm / 100).toFixed(2).replace('.', ',') + ' m';
const caminhoFoto = url => (url || '').split('/object/public/fotos/')[1] || null;

/* ---------- menu e logo ---------- */
function nav(admin, ativo) {
  const links = admin
    ? [['elenco', 'Elenco', 'elenco.html'], ['contato', 'Contato', 'contato.html'], ['config', 'Configurações', 'configuracoes.html']]
    : [['home', 'Início', 'index.html'], ['elenco', 'Elenco', 'elenco.html'], ['contato', 'Contato', 'contato.html']];
  document.getElementById('nav').innerHTML =
    `<a class="logo" href="${admin ? '../index.html' : 'index.html'}"><span class="marca"></span>ETERNUS<b>FC</b>${admin ? '<small>admin</small>' : ''}</a><nav>` +
    links.map(([k, t, h]) => `<a href="${h}" ${k === ativo ? 'aria-current="page"' : ''}>${t}</a>`).join('') +
    (admin ? '<button id="sair" class="link">Sair</button>' : '') + '</nav>';
  if (admin) document.getElementById('sair').onclick = async () => { await sb.auth.signOut(); location.replace('index.html'); };
  carregarLogo();
}

function aplicarLogo(url) {
  document.querySelectorAll('.marca').forEach(m => m.innerHTML = url ? `<img src="${esc(url)}" alt="">` : '');
  const h = document.getElementById('heroLogo');
  if (h) { h.hidden = !url; if (url) h.src = url; }
  if (url) {
    let l = document.querySelector('link[rel=icon]');
    if (!l) { l = document.createElement('link'); l.rel = 'icon'; document.head.append(l); }
    l.href = url;
  }
}

async function carregarLogo() {
  try { aplicarLogo(localStorage.getItem('logo')); } catch (e) {}
  const { data } = await sb.from('configuracoes').select('logo_url').eq('id', 1).maybeSingle();
  const url = data?.logo_url || null;
  try { url ? localStorage.setItem('logo', url) : localStorage.removeItem('logo'); } catch (e) {}
  aplicarLogo(url);
}

/* ---------- login ---------- */
async function usuarioLogado() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return null;
  const { data, error } = await sb.auth.getUser();
  if (error || !data.user) { await sb.auth.signOut({ scope: 'local' }); return null; }
  return data.user;
}
async function exigeLogin() {
  const u = await usuarioLogado();
  if (!u) { location.replace('index.html'); return new Promise(() => {}); }
  return u;
}

function aviso(msg, erro) {
  const el = document.getElementById('aviso');
  el.textContent = msg; el.className = 'aviso ' + (erro ? 'erro' : 'ok'); el.hidden = false;
  clearTimeout(aviso.t); aviso.t = setTimeout(() => el.hidden = true, 4000);
}

/* ---------- elenco ---------- */
const iniciais = n => n.split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase();

function cartaoJogador(j) {
  return `<button class="card" data-id="${j.id}">
    ${j.foto_url ? `<img src="${esc(j.foto_url)}" alt="" loading="lazy">` : `<div class="ini">${esc(iniciais(j.nome))}</div>`}
    <h3>${esc(j.nome)}</h3><p>${esc(j.posicao)}</p></button>`;
}

function detalhesJogador(j) {
  const l = [['Posição', j.posicao], ['Número', j.numero], ['Idade', j.idade && j.idade + ' anos'], ['Altura', j.altura_cm && fmtAltura(j.altura_cm)], ['Pé dominante', j.pe_dominante]]
    .filter(x => x[1]).map(([a, b]) => `<div class="det"><span>${a}</span><span>${esc(b)}</span></div>`).join('');
  return `<button class="fechar" aria-label="Fechar">×</button>
    ${j.foto_url ? `<img src="${esc(j.foto_url)}" alt="">` : `<div class="ini">${esc(iniciais(j.nome))}</div>`}
    <div class="corpo"><h3>${esc(j.nome)}</h3>${l}</div>`;
}

// Reduz a imagem antes de enviar. PNG mantém fundo transparente (logo).
function comprimir(file, max = 900, tipo = 'image/jpeg') {
  return new Promise((ok, err) => {
    const img = new Image(), u = URL.createObjectURL(file);
    img.onload = () => {
      const r = Math.min(1, max / Math.max(img.width, img.height)), c = document.createElement('canvas');
      c.width = Math.round(img.width * r); c.height = Math.round(img.height * r);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(u);
      c.toBlob(b => b ? ok(b) : err(new Error('Não foi possível processar a imagem.')), tipo, .85);
    };
    img.onerror = () => err(new Error('Arquivo de imagem inválido.'));
    img.src = u;
  });
}

/* ---------- contato ---------- */
function linksContato(c) {
  const dig = v => String(v || '').replace(/\D/g, '');
  const ig = String(c.instagram || '').replace(/^@/, '');
  const it = [];
  if (c.whatsapp) it.push(['WhatsApp', c.whatsapp, `https://wa.me/${dig(c.whatsapp)}`]);
  if (c.telefone) it.push(['Telefone', c.telefone, `tel:${dig(c.telefone)}`]);
  if (c.email) it.push(['E-mail', c.email, `mailto:${c.email}`]);
  if (ig) it.push(['Instagram', '@' + ig, `https://instagram.com/${ig}`]);
  if (c.endereco) it.push(['Local', c.endereco, `https://www.google.com/maps/search/${encodeURIComponent(c.endereco)}`]);
  if (c.treinos) it.push(['Treinos', c.treinos, null]);
  return it.map(([t, v, h]) => `<div class="info"><dt>${t}</dt><dd>${h ? `<a href="${esc(h)}" target="_blank" rel="noopener">${esc(v)}</a>` : esc(v)}</dd></div>`).join('');
}
