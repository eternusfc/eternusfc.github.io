const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const POSICOES = ['Goleiro', 'Fixo', 'Ala', 'Pivô', 'Técnico'];
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function nav(admin, ativo) {
  const links = admin
    ? [['elenco', 'Elenco', 'elenco.html'], ['contato', 'Contato', 'contato.html'], ['site', 'Ver site', '../index.html']]
    : [['home', 'Início', 'index.html'], ['elenco', 'Elenco', 'elenco.html'], ['contato', 'Contato', 'contato.html']];
  document.getElementById('nav').innerHTML =
    `<a class="logo" href="${admin ? 'elenco.html' : 'index.html'}">ETERNUS<b>FC</b>${admin ? '<small>admin</small>' : ''}</a><nav>` +
    links.map(([k, t, h]) => `<a href="${h}" ${k === ativo ? 'aria-current="page"' : ''}>${t}</a>`).join('') +
    (admin ? '<button id="sair" class="link">Sair</button>' : '<a class="adm" href="admin/index.html">Admin</a>') + '</nav>';
  if (admin) document.getElementById('sair').onclick = async () => { await sb.auth.signOut(); location.replace('index.html'); };
}

// Valida o login no servidor. Se a sessão guardada for inválida, limpa e volta ao login.
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

const PES = ['Direito', 'Esquerdo', 'Ambidestro'];
const fmtAltura = cm => (cm / 100).toFixed(2).replace('.', ',') + ' m';

function cartaoJogador(j) {
  const ini = j.nome.split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase();
  const meta = [j.idade ? `<span>${esc(j.idade)} anos</span>` : '', j.altura_cm ? `<span>${fmtAltura(j.altura_cm)}</span>` : '',
    j.pe_dominante ? `<span>Pé ${esc(j.pe_dominante.toLowerCase())}</span>` : ''].join('');
  return `<article class="card"><span class="num">${esc(j.numero ?? '–')}</span>
    ${j.foto_url ? `<img src="${esc(j.foto_url)}" alt="${esc(j.nome)}" loading="lazy">` : `<div class="ini">${esc(ini)}</div>`}
    <h3>${esc(j.nome)}</h3><p>${esc(j.posicao)}</p>${meta ? `<div class="meta">${meta}</div>` : ''}</article>`;
}

// Reduz a foto (máx. 900px, JPEG) antes de enviar: fotos de celular são pesadas
function comprimir(file, max = 900) {
  return new Promise((ok, err) => {
    const img = new Image(), u = URL.createObjectURL(file);
    img.onload = () => {
      const r = Math.min(1, max / Math.max(img.width, img.height)), c = document.createElement('canvas');
      c.width = Math.round(img.width * r); c.height = Math.round(img.height * r);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(u);
      c.toBlob(b => b ? ok(b) : err(new Error('Não foi possível processar a imagem.')), 'image/jpeg', .85);
    };
    img.onerror = () => err(new Error('Arquivo de imagem inválido.'));
    img.src = u;
  });
}
const caminhoFoto = url => (url || '').split('/object/public/fotos/')[1] || null;

function linksContato(c) {
  const dig = v => String(v || '').replace(/\D/g, '');
  const ig = String(c.instagram || '').replace(/^@/, '');
  const it = [];
  if (c.whatsapp) it.push(['WhatsApp', c.whatsapp, `https://wa.me/${dig(c.whatsapp)}`]);
  if (c.telefone) it.push(['Telefone', c.telefone, `tel:${dig(c.telefone)}`]);
  if (c.email) it.push(['E-mail', c.email, `mailto:${c.email}`]);
  if (ig) it.push(['Instagram', '@' + ig, `https://instagram.com/${ig}`]);
  if (c.endereco) it.push(['Local dos jogos', c.endereco, `https://www.google.com/maps/search/${encodeURIComponent(c.endereco)}`]);
  if (c.treinos) it.push(['Treinos', c.treinos, null]);
  return it.map(([t, v, h]) => `<div class="info"><dt>${t}</dt><dd>${h ? `<a href="${esc(h)}" target="_blank" rel="noopener">${esc(v)}</a>` : esc(v)}</dd></div>`).join('');
}
